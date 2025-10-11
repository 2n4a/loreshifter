import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/features/games/games_cubit.dart';
import 'package:loreshifter/core/widgets/game_status_chip.dart';

class UserHistoryScreen extends StatefulWidget {
  final int userId;

  const UserHistoryScreen({super.key, required this.userId});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GamesCubit>().loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История игр')),
      body: BlocBuilder<GamesCubit, GamesState>(
        builder: (context, state) {
          if (state is GamesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GamesLoaded) {
            final games =
                state.games
                    .where(
                      (g) => g.players.any((p) => p.user.id == widget.userId),
                    )
                    .toList();
            if (games.isEmpty) {
              return const Center(child: Text('История пуста'));
            }
            return ListView.separated(
              itemCount: games.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _GameTile(game: games[index]),
            );
          }
          if (state is GamesFailure) {
            return Center(child: Text('Ошибка: ${state.message}'));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;

  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(game.name),
      subtitle: Text('Мир: ${game.world.name} • Код: ${game.code}'),
      trailing: GameStatusChip(status: game.status),
    );
  }
}
