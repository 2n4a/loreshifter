import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  dynamic _gameState;
  ChatSegment? _currentChat;
  bool _isSending = false;
  int _selectedTabIndex = 0;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
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
      final cubit = context.read<GameplayCubit>();
      late final StreamSubscription subscription;
      subscription = cubit.stream.listen((state) {
        if (state is GameStateLoaded) {
          if (!mounted) return;
          setState(() {
            _gameState = state.gameState;
          });
          if (_gameState['gameChat'] != null) {
            _loadChat(0);
          }
          subscription.cancel();
        } else if (state is GameplayFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки игры: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });
      await cubit.loadGameState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _loadChat(int chatIndex) async {
    final chatId = _getChatIdFromIndex(chatIndex);
    if (chatId != null) {
      final cubit = context.read<GameplayCubit>();
      late final StreamSubscription subscription;
      subscription = cubit.stream.listen((state) {
        if (state is ChatLoaded) {
          if (!mounted) return;
          setState(() {
            _currentChat = state.chatSegment;
            _selectedTabIndex = chatIndex;
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
          subscription.cancel();
        } else if (state is GameplayFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки чата: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });
      await cubit.loadChat(chatId: chatId);
    }
  }

  int? _getChatIdFromIndex(int index) {
    if (_gameState == null) return null;
    if (index == 0) {
      return _gameState['gameChat']?['chatId'];
    } else if (_gameState['playerChats'] != null &&
        index - 1 < (_gameState['playerChats'] as List).length) {
      return _gameState['playerChats']?[index - 1]?['chatId'];
    } else if (_gameState['adviceChats'] != null) {
      final playerChatsCount =
          (_gameState['playerChats'] as List?)?.length ?? 0;
      if (index - 1 - playerChatsCount <
          (_gameState['adviceChats'] as List).length) {
        return _gameState['adviceChats']?[index -
            1 -
            playerChatsCount]?['chatId'];
      }
    }
    return null;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentChat == null) return;
    final text = _messageController.text;
    _messageController.clear();
    if (!mounted) return;
    setState(() => _isSending = true);
    try {
      final cubit = context.read<GameplayCubit>();
      late final StreamSubscription subscription;
      subscription = cubit.stream.listen((state) {
        if (state is MessageSent) {
          _loadChat(_selectedTabIndex);
          subscription.cancel();
        } else if (state is GameplayFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка отправки: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });
      await cubit.sendMessage(chatId: _currentChat!.chatId, text: text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

  void _selectSuggestion(String suggestion) {
    _messageController.text = suggestion;
  }

  Future<void> _leaveGame() async {
    await context.read<GamesCubit>().leaveGame();
    if (!mounted) return;
    context.go('/');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Игра'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveGame,
            tooltip: 'Выйти из игры',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGameStatusBar(cs),
          if (_gameState == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Column(
                children: [
                  _buildChatTabs(cs),
                  Expanded(
                    child:
                        _currentChat == null
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
    );
  }

  Widget _buildGameStatusBar(ColorScheme cs) {
    if (_gameState == null) return const SizedBox.shrink();
    final status = _gameState['status'] as String? ?? 'waiting';
    String statusText;
    Color statusColor;
    switch (status) {
      case 'waiting':
        statusText = 'Ожидание игроков';
        statusColor = Colors.blue;
        break;
      case 'playing':
        statusText = 'Игра идет';
        statusColor = Colors.green;
        break;
      case 'finished':
        statusText = 'Игра завершена';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Статус неизвестен';
        statusColor = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: statusColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (status == 'waiting' && _isPlayerHost())
            SizedBox(
              width: 148,
              child: NeonButton(
                text: 'Начать игру',
                onPressed: _startGame,
                style: NeonButtonStyle.filled,
                color: Colors.green,
              ),
            ),
          if (status == 'finished' && _isPlayerHost())
            SizedBox(
              width: 168,
              child: NeonButton(
                text: 'Начать заново',
                onPressed: _restartGame,
                style: NeonButtonStyle.filled,
                color: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  bool _isPlayerHost() {
    if (_gameState == null || _currentUserId == null) return false;
    final hostId = _gameState['game']?['hostId'];
    return hostId == _currentUserId;
  }

  Future<void> _startGame() async {
    try {
      final cubit = context.read<GameplayCubit>();
      late final StreamSubscription subscription;
      
      subscription = cubit.stream.listen((state) {
        if (state is GameStarted) {
          if (!mounted) return;
          subscription.cancel();
          _loadGameState();
        } else if (state is GameplayFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка при запуске игры: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });
      
      await cubit.startGame();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при запуске игры: $e')));
      }
    }
  }

  Future<void> _restartGame() async {
    try {
      final cubit = context.read<GameplayCubit>();
      late final StreamSubscription subscription;
      
      subscription = cubit.stream.listen((state) {
        if (state is GameRestarted) {
          if (!mounted) return;
          subscription.cancel();
          _loadGameState();
        } else if (state is GameplayFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка при перезапуске игры: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });
      
      await cubit.restartGame();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при перезапуске игры: $e')),
        );
      }
    }
  }

  Widget _buildChatTabs(ColorScheme cs) {
    if (_gameState == null) return const SizedBox.shrink();

    final tabs = <Widget>[];
    tabs.add(_buildTabItem('Общий', 0, cs));

    final playerChats = _gameState['playerChats'] as List?;
    if (playerChats != null) {
      for (int i = 0; i < playerChats.length; i++) {
        final playerChat = playerChats[i];
        final playerName =
            playerChat['playerName'] as String? ?? 'Игрок ${i + 1}';
        tabs.add(_buildTabItem(playerName, i + 1, cs));
      }
    }

    final adviceChats = _gameState['adviceChats'] as List?;
    if (adviceChats != null) {
      final playerChatsCount = playerChats?.length ?? 0;
      for (int i = 0; i < adviceChats.length; i++) {
        final adviceChat = adviceChats[i];
        final adviceTitle = adviceChat['title'] as String? ?? 'Совет ${i + 1}';
        tabs.add(_buildTabItem(adviceTitle, i + 1 + playerChatsCount, cs));
      }
    }

    return Container(
      color: cs.surface,
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, children: tabs),
    );
  }

  Widget _buildTabItem(String text, int index, ColorScheme cs) {
    final isSelected = _selectedTabIndex == index;
    final bg = isSelected ? cs.primary : Colors.transparent;
    final border = isSelected ? Colors.transparent : cs.outlineVariant;
    final fg = isSelected ? Colors.white : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: () => _loadChat(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
          border: Border.all(color: border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
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
            Text('Выберите чат', style: TextStyle(color: cs.onSurfaceVariant)),
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
    TextStyle nameStyle = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

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
                  if ((!isCurrentUser && message.sender.type == 'user') ||
                      message.sender.type == 'system')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(message.sender.name, style: nameStyle),
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
        children:
            suggestions.map((s) {
              return GestureDetector(
                onTap: () => _selectSuggestion(s),
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
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Введите сообщение...',
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
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
                icon: Icon(Icons.send, color: cs.primary),
                onPressed: _sendMessage,
              ),
        ],
      ),
    );
  }
}
