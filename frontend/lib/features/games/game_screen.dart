import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/chat/domain/models/game_state.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/message.dart';
import '/features/auth/auth_cubit.dart';
import '/features/chat/gameplay_cubit.dart';
import '/features/games/games_cubit.dart';
import '/core/widgets/neon_button.dart';

class GameScreen extends StatefulWidget {
  final int gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  GameState? _gameState;
  ChatSegment? _currentChat;
  bool _isSending = false;
  int _selectedTabIndex = 0;
  int? _currentUserId;
  late TabController _tabController;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _tabController = TabController(length: 1, vsync: this); // Default to 1 tab
    _loadGameState();
  }

  void _getCurrentUserId() {
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.id;
    }
  }


  Future<void> _loadGameState() async {
    try {
      await context.read<GameplayCubit>().loadGameState(widget.gameId);
      final state = context.read<GameplayCubit>().state;
      if (state is GameStateLoaded) {
        setState(() {
          _gameState = state.gameState;
          _updateTabController();
        });
        // Load the first chat by default
        if (_gameState != null) {
          _loadChat(0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки игры: $e')),
        );
      }
    }
  }

  void _updateTabController() {
    if (_gameState == null) return;

    // Calculate number of tabs: General chat + Game chat + n player chats
    int tabCount = 2; // General + Game chat
    tabCount += _gameState!.playerChats.length; // + player chats

    if (_tabController.length != tabCount) {
      _tabController.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          _loadChat(_tabController.index);
        }
      });
    }
  }

  Future<void> _loadChat(int index) async {
    final chatSegment = _getChatFromIndex(index);
    if (chatSegment != null) {
      setState(() {
        _currentChat = chatSegment;
        _selectedTabIndex = index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  ChatSegment? _getChatFromIndex(int index) {
    if (_gameState == null) return null;

    if (index == 0) {
      // General chat - use character creation chat or game chat as fallback
      return _gameState!.gameChat ?? _gameState!.characterCreationChat;
    } else if (index == 1) {
      // Game chat
      return _gameState!.gameChat;
    } else {
      // Player chats (index - 2)
      final playerChatIndex = index - 2;
      if (playerChatIndex < _gameState!.playerChats.length) {
        return _gameState!.playerChats[playerChatIndex];
      }
    }
    return null;
  }

  Future<void> _loadChatById(int chatId) async {
    try {
      await context.read<GameplayCubit>().loadChat(
        gameId: widget.gameId,
        chatId: chatId,
      );
      final state = context.read<GameplayCubit>().state;
      if (state is ChatLoaded) {
        setState(() {
          _currentChat = state.chatSegment;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки чата: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentChat == null) return;
    
    final text = _messageController.text;
    _messageController.clear();
    
    setState(() => _isSending = true);
    
    try {
      await context.read<GameplayCubit>().sendMessage(
        gameId: widget.gameId,
        chatId: _currentChat!.chatId,
        text: text,
      );
      
      // Reload the current chat
      if (_selectedTabIndex == 0) {
        // General chat - reload game state
        await _loadGameState();
      } else {
        // Reload game state to get updated chats
        await _loadGameState();
        _loadChat(_selectedTabIndex);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _canWriteInCurrentChat() {
    if (_gameState == null || _currentChat == null) return false;

    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return false;

    final currentPlayer = _gameState!.game.players.firstWhere(
      (p) => p.user.id == authState.user.id,
      orElse: () => _gameState!.game.players.first,
    );

    // Spectators can't write in game chat (index 1)
    if (_selectedTabIndex == 1 && currentPlayer.isSpectator) {
      return false;
    }

    // Player chats: only owner can write
    if (_selectedTabIndex >= 2) {
      final playerChatIndex = _selectedTabIndex - 2;
      if (playerChatIndex < _gameState!.playerChats.length) {
        final playerChat = _gameState!.playerChats[playerChatIndex];
        return playerChat.chatOwner == authState.user.id;
      }
    }

    // General chat: everyone can write
    return true;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Игра'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'На главную',
        ),
      ),
      body: BlocListener<GameplayCubit, GameplayState>(
        listener: (context, state) {
          if (state is GameStateLoaded) {
            setState(() {
              _gameState = state.gameState;
              _updateTabController();
            });
          } else if (state is ChatLoaded && _selectedTabIndex == 0) {
            setState(() {
              _currentChat = state.chatSegment;
            });
          }
        },
        child: Column(
          children: [
            if (_gameState == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  children: [
                    _buildChatTabs(cs),
                    Expanded(
                      child: _currentChat == null
                          ? _buildEmptyChat(cs)
                          : _buildChatMessages(cs),
                    ),
                    if (_currentChat != null) _buildSuggestions(cs),
                    _buildMessageInput(cs),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTabs(ColorScheme cs) {
    if (_gameState == null) return const SizedBox.shrink();

    return Container(
      color: cs.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          const Tab(text: 'Общий чат'),
          const Tab(text: 'Игровой чат'),
          ..._gameState!.playerChats.map((playerChat) {
            // Find player name from game.players using chatOwner
            String playerName = 'Игрок';
            if (playerChat.chatOwner != null) {
              final player = _gameState!.game.players.firstWhere(
                (p) => p.user.id == playerChat.chatOwner,
                orElse: () => _gameState!.game.players.first,
              );
              playerName = player.user.name;
            }
            return Tab(text: 'Чат $playerName');
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(ColorScheme cs) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Загрузка чата...', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages(ColorScheme cs) {
    if (_currentChat == null) return const SizedBox.shrink();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _currentChat!.messages.length,
      itemBuilder: (context, index) {
        final message = _currentChat!.messages[index];
        return _buildMessageBubble(message, cs);
      },
    );
  }

  Widget _buildMessageBubble(Message message, ColorScheme cs) {
    final isCurrentUser = message.senderId == _currentUserId;

    Color bubbleColor;
    BorderRadius borderRadius;
    Color borderColor = Colors.transparent;
    Color textColor = cs.onSurface;

    if (message.sender.type == 'system') {
      bubbleColor = cs.surfaceContainerHighest;
      borderRadius = BorderRadius.circular(12);
      textColor = cs.onSurfaceVariant;
      borderColor = cs.outlineVariant;
    } else if (message.sender.type == 'assistant') {
      bubbleColor = cs.secondaryContainer;
      borderRadius = BorderRadius.circular(16);
      textColor = cs.onSecondaryContainer;
    } else if (isCurrentUser) {
      bubbleColor = cs.primaryContainer;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
      textColor = cs.onPrimaryContainer;
    } else {
      bubbleColor = cs.tertiaryContainer;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
      textColor = cs.onTertiaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser && message.sender.type == 'user')
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                message.sender.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!isCurrentUser && message.sender.type != 'system')
            const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderColor,
                  width: borderColor == Colors.transparent ? 0 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && message.sender.type == 'user')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender.name,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(message.text, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                message.sender.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme cs) {
    final suggestions = _currentChat?.suggestions ?? [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((s) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _messageController.text = s;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(s, style: TextStyle(color: cs.onSurface)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme cs) {
    final canWrite = _canWriteInCurrentChat();
    final hintText = canWrite
        ? 'Введите сообщение...'
        : 'Вы не можете писать в этот чат';

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: hintText,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: canWrite ? (_) => _sendMessage() : null,
              enabled: canWrite,
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(Icons.send, color: canWrite ? cs.primary : cs.onSurfaceVariant),
                  onPressed: canWrite ? _sendMessage : null,
                ),
        ],
      ),
    );
  }
}
