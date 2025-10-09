import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/features/games/games_cubit.dart';

class GameDetailScreen extends StatefulWidget {
  final int? gameId;
  final String? code;

  const GameDetailScreen({
    super.key,
    this.gameId,
    this.code,
  }) : assert(gameId != null || code != null, 'Необходимо указать gameId или code');

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadGameDetails();
  }

  Future<void> _loadGameDetails() async {
    if (widget.gameId != null) {
      await context.read<GamesCubit>().loadGameById(widget.gameId!);
    } else if (widget.code != null) {
      await context.read<GamesCubit>().loadGameByCode(widget.code!);
    }
  }

  Future<void> _joinGame() async {
    setState(() {
      _isJoining = true;
    });

    try {
      final gamesCubit = context.read<GamesCubit>();

      if (widget.gameId != null) {
        await gamesCubit.joinGame(gameId: widget.gameId);
      } else if (widget.code != null) {
        await gamesCubit.joinGame(code: widget.code);
      }

      if (!mounted) return;

      context.go('/game');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при присоединении к игре: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали игры'),
      ),
      body: BlocBuilder<GamesCubit, GamesState>(
        builder: (context, state) {
          if (state is GamesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GameLoaded) {
            final game = state.game;
            return _buildGameDetails(game);
          }

          if (state is GamesFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ошибка: ${state.message}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadGameDetails,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Text('Загрузите информацию о игре'),
          );
        },
      ),
    );
  }

  Widget _buildGameDetails(Game game) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Карточка с основной информацией об игре
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      _buildGameStatusChip(game.status),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Мир', game.world.name),
                  _buildInfoRow('Публичная', game.public ? 'Да' : 'Нет'),
                  _buildInfoRow('Код доступа', game.code),
                  _buildInfoRow('Создана', _formatDate(game.createdAt)),
                  _buildInfoRow('Игроков', '${game.players.length}/${game.maxPlayers}'),
                ],
              ),
            ),
          ),

          // Список игроков
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Игроки',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                if (game.players.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Нет игроков'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: game.players.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final player = game.players[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            player.user.name.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(player.user.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (player.isHost)
                              Chip(
                                label: const Text('Хост'),
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                side: BorderSide(color: Colors.amber.shade700),
                              ),
                            if (player.isReady)
                              const SizedBox(width: 8),
                            if (player.isReady)
                              const Chip(
                                label: Text('Готов'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Информация о мире
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'О мире',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.world.description ?? 'Описание отсутствует',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Создатель мира: ${game.world.owner.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Кнопка для присоединения к игре
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isJoining ? null : _joinGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isJoining
                  ? const CircularProgressIndicator()
                  : const Text('Присоединиться к игре'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStatusChip(GameStatus status) {
    String text;
    Color color;

    switch (status) {
      case GameStatus.waiting:
        text = 'Ожидание';
        color = Colors.blue;
        break;
      case GameStatus.playing:
        text = 'В процессе';
        color = Colors.green;
        break;
      case GameStatus.finished:
        text = 'Завершена';
        color = Colors.orange;
        break;
      case GameStatus.archived:
        text = 'В архиве';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
