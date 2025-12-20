import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/games/domain/models/game.dart';
import '/features/games/games_cubit.dart';
import '/features/auth/auth_cubit.dart';
import '/features/games/presentation/widgets/game_status_chip.dart';
import '/features/chat/gameplay_cubit.dart';
import '/features/chat/domain/models/game_state.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/message.dart';
import '/core/widgets/neon_button.dart';
import '/core/widgets/modern_card.dart';

class GameLobbyScreen extends StatefulWidget {
  final int? gameId;
  final String? code;

  const GameLobbyScreen({super.key, this.gameId, this.code})
      : assert(
          gameId != null || code != null,
          'Необходимо указать gameId или code',
        );

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen>
    with SingleTickerProviderStateMixin {
  bool _isJoining = false;
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  int? _currentGameId;
  GameState? _gameState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGameDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadGameDetails() async {
    if (widget.gameId != null) {
      await context.read<GamesCubit>().loadGameById(widget.gameId!);
      _currentGameId = widget.gameId;
    } else if (widget.code != null) {
      await context.read<GamesCubit>().loadGameByCode(widget.code!);
    }

    if (!mounted) return;

    // Load game state
    final state = context.read<GamesCubit>().state;
    if (state is GameLoaded) {
      _currentGameId = state.game.id;
      await _loadGameState();
    }
  }

  Future<void> _loadGameState() async {
    if (_currentGameId != null) {
      await context.read<GameplayCubit>().loadGameState(_currentGameId!);
    }
  }

  // WebSocket methods removed - polling will be used for updates

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

      final state = gamesCubit.state;
      if (state is GameJoined) {
        _currentGameId = state.game.id;
        await _loadGameState();
        await _loadGameDetails();
      }
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

  Future<void> _toggleReady() async {
    if (_currentGameId == null) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;

    final game = (context.read<GamesCubit>().state as GameLoaded).game;
    final currentPlayer = game.players.firstWhere(
      (p) => p.user.id == authState.user.id,
    );

    await context
        .read<GameplayCubit>()
        .setReady(_currentGameId!, !currentPlayer.isReady);

    // Reload game state
    await _loadGameState();
    await _loadGameDetails();
  }

  Future<void> _startGame() async {
    if (_currentGameId == null) return;

    try {
      await context.read<GameplayCubit>().startGame(_currentGameId!);
      // WebSocket will handle navigation
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при запуске игры: $e')),
      );
    }
  }

  Future<void> _leaveGame(int gameId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Покинуть игру'),
        content: const Text('Вы уверены, что хотите покинуть эту игру?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Покинуть',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<GamesCubit>().leaveGame(gameId);
        if (mounted) {
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лобби игры')),
      body: BlocListener<GameplayCubit, GameplayState>(
        listener: (context, state) {
          if (state is GameStateLoaded) {
            setState(() {
              _gameState = state.gameState;
            });
          }
        },
        child: BlocBuilder<GamesCubit, GamesState>(
          builder: (context, state) {
            if (state is GamesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is GameLoaded) {
              final game = state.game;
              return _buildLobby(game);
            }

            if (state is GamesFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ошибка: ${state.message}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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

            return const Center(child: Text('Загрузите информацию о игре'));
          },
        ),
      ),
    );
  }

  Widget _buildLobby(Game game) {
    final authState = context.read<AuthCubit>().state;
    final isAuthenticated = authState is Authenticated;
    final isPlayer = isAuthenticated &&
        game.players.any((p) => p.user.id == authState.user.id);
    final isSpectator = isPlayer &&
        game.players
            .firstWhere((p) => p.user.id == authState.user.id)
            .isSpectator;

    // Adjust tab count dynamically
    final tabCount = isSpectator ? 1 : 2;
    if (_tabController.length != tabCount) {
      _tabController.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
    }

    return Column(
      children: [
        // Game info card
        ModernCard(
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    GameStatusChip(status: game.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Мир: ${game.world.name}'),
                Text('Код: ${game.code}'),
              ],
            ),
          ),
        ),

        // Player list
        Expanded(
          flex: 2,
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Игроки (${game.players.length}/${game.maxPlayers})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: game.players.length,
                    itemBuilder: (context, index) {
                      final player = game.players[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            player.user.name.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(player.user.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (player.isHost)
                              const Chip(
                                label: Text('Хост'),
                                backgroundColor: Colors.amber,
                              ),
                            if (player.isSpectator)
                              const Chip(
                                label: Text('Наблюдатель'),
                                backgroundColor: Colors.grey,
                              ),
                            if (!player.isHost && !player.isSpectator)
                              const Chip(
                                label: Text('Игрок'),
                                backgroundColor: Colors.blue,
                              ),
                            if (player.isReady) const SizedBox(width: 8),
                            if (player.isReady)
                              const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chats
        Expanded(
          flex: 3,
          child: ModernCard(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    const Tab(text: 'Общий чат'),
                    if (!isSpectator) const Tab(text: 'Создание персонажа'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChatView(isGeneralChat: true),
                      if (!isSpectator)
                        _buildChatView(isGeneralChat: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: isPlayer
              ? _buildPlayerButtons(game, isSpectator)
              : _buildJoinButton(),
        ),
      ],
    );
  }

  Widget _buildChatView({required bool isGeneralChat}) {
    return BlocBuilder<GameplayCubit, GameplayState>(
      builder: (context, state) {
        List<Message> messages = [];

        if (_gameState != null) {
          if (isGeneralChat) {
            // General chat (room/lobby chat) - Use character creation chat as fallback
            // In waiting state, there's no separate general chat, use character creation
          } else {
            // Character creation chat
            final characterChat = _gameState!.characterCreationChat;
            if (characterChat != null) {
              messages = characterChat.messages;
            }
          }
        }

        if (state is ChatLoaded && isGeneralChat) {
          messages = state.chatSegment.messages;
        }

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        isGeneralChat
                            ? 'Нет сообщений в общем чате'
                            : 'Создайте своего персонажа здесь',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        return _buildMessage(message);
                      },
                    ),
            ),
            const Divider(height: 1),
            _buildMessageInput(isGeneralChat),
          ],
        );
      },
    );
  }

  Widget _buildMessage(Message message) {
    final authState = context.read<AuthCubit>().state;
    final isOwn = authState is Authenticated &&
        message.senderId == authState.user.id;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwn)
              Text(
                message.sender.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(message.text),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isGeneralChat) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: isGeneralChat
                    ? 'Сообщение в общий чат...'
                    : 'Опишите своего персонажа...',
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(isGeneralChat),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(bool isGeneralChat) async {
    if (_messageController.text.isEmpty || _currentGameId == null) return;
    if (_gameState == null) return;

    final content = _messageController.text;
    _messageController.clear();

    int chatId;
    if (isGeneralChat) {
      // Use character creation chat in lobby for general chat
      chatId = _gameState!.characterCreationChat!.chatId;
    } else {
      chatId = _gameState!.characterCreationChat!.chatId;
    }

    await context.read<GameplayCubit>().sendMessage(
      gameId: _currentGameId!,
      chatId: chatId,
      text: content,
    );

    // Reload chat
    await context.read<GameplayCubit>().loadChat(
      gameId: _currentGameId!,
      chatId: chatId,
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      child: NeonButton(
        text: _isJoining ? 'Присоединение...' : 'Присоединиться',
        onPressed: _isJoining ? null : _joinGame,
        style: NeonButtonStyle.filled,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildPlayerButtons(Game game, bool isSpectator) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return const SizedBox.shrink();

    final isHost = game.hostId == authState.user.id;
    final currentPlayer = game.players.firstWhere(
      (p) => p.user.id == authState.user.id,
    );

    final readyCount = game.players.where((p) => p.isReady && !p.isSpectator).length;
    final totalPlayers = game.players.where((p) => !p.isSpectator).length;
    final allReady = totalPlayers > 0 && readyCount == totalPlayers;

    return Column(
      children: [
        if (!isSpectator) ...[
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              text: currentPlayer.isReady
                  ? 'Готов ($readyCount/$totalPlayers)'
                  : 'Не готов ($readyCount/$totalPlayers)',
              onPressed: _toggleReady,
              style: NeonButtonStyle.filled,
              color: currentPlayer.isReady ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (isHost && allReady)
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              text: 'Начать игру',
              onPressed: _startGame,
              style: NeonButtonStyle.filled,
              color: Colors.green,
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: NeonButton(
            text: 'Покинуть игру',
            onPressed: () => _leaveGame(game.id),
            style: NeonButtonStyle.outlined,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}
