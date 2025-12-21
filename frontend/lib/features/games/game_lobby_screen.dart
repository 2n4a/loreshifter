import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  GameplayCubit? _gameplayCubit;
  bool _isDisposed = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  int? _loadedChatId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadGameDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameplayCubit ??= context.read<GameplayCubit>();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _messageController.dispose();
    _wsSubscription?.cancel();
    _gameplayCubit?.disconnectWebSocket();
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

    // Load game state and connect to WebSocket
    final state = context.read<GamesCubit>().state;
    if (state is GameLoaded) {
      _currentGameId = state.game.id;
      await _loadGameState();
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (_currentGameId == null) return;

    _wsSubscription?.cancel();
    _wsSubscription = context
        .read<GameplayCubit>()
        .connectWebSocket(_currentGameId!)
        .listen((event) async {
      if (_isDisposed) return;

      final type = event['type'] as String?;
      final payload = event['payload'] as Map<String, dynamic>?;

      // Handle connection state changes
      if (type == '_connection_state' && payload != null) {
        final state = payload['state'] as String?;
        final attempts = payload['attempts'] as int? ?? 0;
        
        if (!mounted) return;
        
        setState(() {
          _isReconnecting = state == 'reconnecting';
          _reconnectAttempts = attempts;
        });

        if (state == 'disconnected' && attempts >= 10) {
          // Max reconnect attempts reached
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Соединение потеряно. Пожалуйста, обновите страницу.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        } else if (state == 'connected' && attempts > 0) {
          // Successfully reconnected
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Соединение восстановлено'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Reload state after reconnection
            await _loadGameState();
            await _loadGameDetails();
          }
        }
        return;
      }

      if (type == 'GameStatusEvent' && payload != null) {
        final newStatus = payload['new_status'] as String?;
        if (newStatus == 'playing') {
          // Game started, navigate to game screen
          if (mounted && !_isDisposed) {
            await _wsSubscription?.cancel();
            _wsSubscription = null;
            if (mounted) {
              context.push('/game/$_currentGameId');
            }
          }
        } else {
          // Reload game state
          if (!_isDisposed && mounted) {
            await _loadGameState();
            await _loadGameDetails();
          }
        }
      } else if (type == 'PlayerJoinedEvent' ||
          type == 'PlayerLeftEvent' ||
          type == 'PlayerKickedEvent' ||
          type == 'PlayerReadyEvent') {
        // Reload game details and state
        if (!_isDisposed && mounted) {
          await _loadGameState();
          await _loadGameDetails();
        }
      } else if (type == 'GameChatEvent') {
        if (_isDisposed || !mounted) return;
        if (_currentGameId == null || _gameState == null) return;

        final chatId = payload?['chat_id'] ?? payload?['chatId'];
        if (chatId is! int) return;

        final isGeneralChat = _tabController.index == 0;
        final expectedChatId = isGeneralChat
            ? _gameState!.gameChat?.chatId ?? _gameState!.characterCreationChat?.chatId
            : _gameState!.characterCreationChat?.chatId;

        if (chatId != expectedChatId) {
          return;
        }

        try {
          await context.read<GameplayCubit>().loadChat(
            gameId: _currentGameId!,
            chatId: chatId,
          );
          if (mounted) {
            setState(() {
              _loadedChatId = chatId;
            });
          }
        } catch (e) {
          developer.log('[GAME_LOBBY] Failed to refresh chat: $e', error: e);
        }
      }
    }, onError: (error) {
      if (_isDisposed || !mounted) return;
      
      developer.log('[GAME_LOBBY] WebSocket error: $error', error: error);
    });
  }

  void _disconnectWebSocket() {
    _wsSubscription?.cancel();
    _gameplayCubit?.disconnectWebSocket();
  }

  Future<void> _loadGameState() async {
    if (_currentGameId != null) {
      await context.read<GameplayCubit>().loadGameState(_currentGameId!);
      
      // Load the initial chat after game state is loaded
      if (mounted && !_isDisposed) {
        await _loadCurrentChat();
      }
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted && !_isDisposed) {
      _loadCurrentChat();
    }
  }

  Future<void> _loadCurrentChat() async {
    if (_currentGameId == null || _gameState == null) return;

    final isGeneralChat = _tabController.index == 0;
    
    int? chatId;
    if (isGeneralChat) {
      chatId = _gameState!.gameChat?.chatId ?? _gameState!.characterCreationChat?.chatId;
    } else {
      chatId = _gameState!.characterCreationChat?.chatId;
    }

    if (chatId != null) {
      try {
        await context.read<GameplayCubit>().loadChat(
          gameId: _currentGameId!,
          chatId: chatId,
        );
        
        if (mounted) {
          setState(() {
            _loadedChatId = chatId;
          });
        }
      } catch (e) {
        developer.log('[GAME_LOBBY] Failed to load chat: $e', error: e);
      }
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

      final state = gamesCubit.state;
      if (state is GameJoined) {
        _currentGameId = state.game.id;
        await _loadGameState();
        _connectWebSocket();
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

  bool _isTogglingReady = false;

  Future<void> _toggleReady() async {
    if (_currentGameId == null || _isTogglingReady) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;

    final game = (context.read<GamesCubit>().state as GameLoaded).game;
    final currentPlayer = game.players.firstWhere(
      (p) => p.user.id == authState.user.id,
    );

    setState(() {
      _isTogglingReady = true;
    });

    try {
      await context
          .read<GameplayCubit>()
          .setReady(_currentGameId!, !currentPlayer.isReady);
      // WebSocket will automatically update the game state via PlayerReadyEvent
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingReady = false;
        });
      }
    }
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
        // Disconnect WebSocket first and wait for it to complete
        await _wsSubscription?.cancel();
        _wsSubscription = null;
        _gameplayCubit?.disconnectWebSocket();
        
        // Small delay to ensure WebSocket is fully closed
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        await context.read<GamesCubit>().leaveGame(gameId);
        if (mounted) {
          // Reload games list before navigating back
          await context.read<GamesCubit>().loadGames();
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
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Лобби игры'),
            if (_isReconnecting) ...[  
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Переподключение...',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      body: BlocListener<GameplayCubit, GameplayState>(
        listener: (context, state) {
          if (_isDisposed) return;
          
          if (state is GameStateLoaded) {
            // Check if game has started BEFORE updating state to prevent rebuild
            if (state.gameState.status == GameStatus.playing && _currentGameId != null) {
              if (mounted) {
                _wsSubscription?.cancel();
                _wsSubscription = null;
                context.push('/game/$_currentGameId');
              }
              return;
            }
            
            // Only update state if not navigating away
            if (mounted) {
              setState(() {
                _gameState = state.gameState;
              });
            }
          } else if (state is GameplayFailure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка: ${state.message}')),
              );
            }
          }
        },
        child: BlocBuilder<GamesCubit, GamesState>(
          builder: (context, state) {
            // Return early if widget is disposed to prevent TabController errors
            if (_isDisposed) {
              return const SizedBox.shrink();
            }
            
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
                    const SizedBox(height: 12),
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
    // Return early if disposed to prevent using disposed TabController
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

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
      // Schedule tab controller update for after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          setState(() {
            _tabController.dispose();
            _tabController = TabController(length: tabCount, vsync: this);
          });
        }
      });
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
                const SizedBox(height: 12),
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
                                label: Text('Хост', style: TextStyle(color: Colors.black)),
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
        int? expectedChatId;

        if (_gameState != null) {
          if (isGeneralChat) {
            // General chat - use gameChat if available, fallback to character creation
            final generalChat = _gameState!.gameChat ?? _gameState!.characterCreationChat;
            if (generalChat != null) {
              messages = generalChat.messages;
              expectedChatId = generalChat.chatId;
            }
          } else {
            // Character creation chat
            final characterChat = _gameState!.characterCreationChat;
            if (characterChat != null) {
              messages = characterChat.messages;
              expectedChatId = characterChat.chatId;
            }
          }
        }

        // Use ChatLoaded state if it matches the expected chat for this tab
        if (state is ChatLoaded && state.chatSegment.chatId == expectedChatId) {
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                  final keys = HardwareKeyboard.instance.logicalKeysPressed;
                  final shiftDown = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                      keys.contains(LogicalKeyboardKey.shiftRight);
                  if (!shiftDown) {
                    _sendMessage(isGeneralChat);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: isGeneralChat
                      ? 'Сообщение в общий чат...'
                      : 'Опишите своего персонажа...',
                  border: const OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(isGeneralChat),
              ),
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
      // Use game chat for general chat, fallback to character creation chat if not available
      chatId = _gameState!.gameChat?.chatId ?? _gameState!.characterCreationChat!.chatId;
    } else {
      chatId = _gameState!.characterCreationChat!.chatId;
    }

    try {
      await context.read<GameplayCubit>().sendMessage(
        gameId: _currentGameId!,
        chatId: chatId,
        text: content,
      );

      // Reload chat to get updated messages
      await context.read<GameplayCubit>().loadChat(
        gameId: _currentGameId!,
        chatId: chatId,
      );
      
      // Track which chat was loaded for UI updates
      if (mounted) {
        setState(() {
          _loadedChatId = chatId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
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
                  : 'Готов',
              onPressed: _isTogglingReady ? null : _toggleReady,
              style: NeonButtonStyle.filled,
              color: currentPlayer.isReady ? Colors.green.shade700 : Colors.green,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isHost)
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              text: allReady ? 'Начать игру' : 'Ожидание игроков ($readyCount/$totalPlayers)',
              onPressed: allReady ? _startGame : null,
              style: NeonButtonStyle.filled,
              color: allReady ? Colors.green : Colors.green.shade900.withOpacity(0.5),
            ),
          ),
        if (isHost) const SizedBox(height: 12),
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
