import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/message.dart';
import '/features/auth/auth_cubit.dart';
import '/features/chat/gameplay_cubit.dart';
import '/features/games/games_cubit.dart';
import '/core/theme/app_theme.dart';

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
    debugPrint('DEBUG: Загрузка состояния игры для gameId=${widget.gameId}');
    try {
      // Регистрируем слушатель перед вызовом loadGameState
      final cubit = context.read<GameplayCubit>();

      // Подписываемся на изменения состояния
      late final StreamSubscription subscription;
      subscription = cubit.stream.listen((state) {
        debugPrint(
          'DEBUG: Получено новое состояние GameplayCubit: ${state.runtimeType}',
        );

        if (state is GameStateLoaded) {
          debugPrint('DEBUG: Состояние успешно загружено!');
          if (!mounted) return; // защитная проверка
          setState(() {
            _gameState = state.gameState;
          });
          debugPrint('DEBUG: Состояние игры: $_gameState');

          // Загружаем основной игровой чат
          if (_gameState['gameChat'] != null) {
            debugPrint('DEBUG: Найден gameChat, загружаем чат с индексом 0');
            _loadChat(0); // Индекс 0 для основного чата
          } else {
            debugPrint('DEBUG: ОШИБКА - gameChat не найден в состоянии игры');
          }
          subscription.cancel();
        } else if (state is GameplayFailure) {
          debugPrint('DEBUG: ОШИБКА ЗАГРУЗКИ: ${state.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки игры: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });

      // Теперь вызываем загрузку состояния
      await cubit.loadGameState();
      debugPrint('DEBUG: Запрос на загрузку состояния игры отправлен');
    } catch (e, stacktrace) {
      debugPrint('DEBUG: ИСКЛЮЧЕНИЕ при загрузке состояния игры: $e');
      debugPrint('DEBUG: Стек вызовов: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _loadChat(int chatIndex) async {
    debugPrint('DEBUG: Начинаем загрузку чата с индексом $chatIndex');
    final chatId = _getChatIdFromIndex(chatIndex);
    if (chatId != null) {
      debugPrint('DEBUG: Получен chatId: $chatId');

      // Регистрируем слушатель для получения обновлений состояния
      final cubit = context.read<GameplayCubit>();

      // Создаем переменную для подписки без инициализации
      late final StreamSubscription subscription;

      // Теперь инициализируем её
      subscription = cubit.stream.listen((state) {
        debugPrint(
          'DEBUG: Получено состояние при загрузке чата: ${state.runtimeType}',
        );

        if (state is ChatLoaded) {
          debugPrint('DEBUG: Чат успешно загружен: ${state.chatSegment.chatId}');
          if (!mounted) return; // защитная проверка
          setState(() {
            _currentChat = state.chatSegment;
            _selectedTabIndex = chatIndex;
          });

          // Прокручиваем чат вниз, чтобы видеть последние сообщения
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          subscription.cancel();
        } else if (state is GameplayFailure) {
          debugPrint('DEBUG: Ошибка загрузки чата: ${state.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки чата: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });

      // Теперь запрашиваем загрузку чата
      await cubit.loadChat(chatId: chatId);
      debugPrint('DEBUG: Запрос на загрузку чата отправлен');
    } else {
      debugPrint('DEBUG: Не удалось получить chatId для индекса $chatIndex');
    }
  }

  // Метод для получения ID чата по индексу вкладки
  int? _getChatIdFromIndex(int index) {
    if (_gameState == null) return null;

    if (index == 0) {
      // Общий игровой чат
      return _gameState['gameChat']?['chatId'];
    } else if (_gameState['playerChats'] != null &&
        index - 1 < (_gameState['playerChats'] as List).length) {
      // Индивидуальные чаты игроков
      return _gameState['playerChats']?[index - 1]?['chatId'];
    } else if (_gameState['adviceChats'] != null) {
      // Чаты для советов
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

  // Отправить сообщение
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentChat == null) return;

    final text = _messageController.text;
    _messageController.clear();

    debugPrint(
      'DEBUG: Начинаем отправку сообщения: "$text" в чат ${_currentChat!.chatId}',
    );

    if (!mounted) return; // защита от гонок
    setState(() {
      _isSending = true;
    });

    try {
      final cubit = context.read<GameplayCubit>();

      // Объявляем переменную с ключевым словом late
      late final StreamSubscription subscription;

      // Затем инициализируем её
      subscription = cubit.stream.listen((state) {
        debugPrint('DEBUG: Получено состояние при отправке: ${state.runtimeType}');

        if (state is MessageSent) {
          debugPrint('DEBUG: Сообщение успешно отправлено: ${state.message.id}');
          // После успешной отправки загружаем обновленный чат
          _loadChat(_selectedTabIndex);
          subscription.cancel();
        } else if (state is GameplayFailure) {
          debugPrint('DEBUG: Ошибка отправки сообщения: ${state.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка отправки: ${state.message}')),
            );
          }
          subscription.cancel();
        }
      });

      // Отправляем сообщение
      await cubit.sendMessage(chatId: _currentChat!.chatId, text: text);
      debugPrint('DEBUG: Запрос на отправку сообщения выполнен');
    } catch (e, stacktrace) {
      debugPrint('DEBUG: ИСКЛЮЧЕНИЕ при отправке сообщения: $e');
      debugPrint('DEBUG: Стек вызовов: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
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

  // Выбрать подсказку из предложенных вариантов
  void _selectSuggestion(String suggestion) {
    _messageController.text = suggestion;
  }

  // Выход из игры
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkAccent,
        title: AppTheme.gradientText(
          text: 'ИГРА',
          gradient: AppTheme.purpleToPinkGradient,
          fontSize: 22.0,
        ),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppTheme.neonShadow(AppTheme.neonPink),
            ),
            child: IconButton(
              icon: Icon(Icons.exit_to_app, color: AppTheme.neonPink),
              onPressed: _leaveGame,
              tooltip: 'Выйти из игры',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGameStatusBar(),
          if (_gameState == null)
            Expanded(
              child: Center(
                child: AppTheme.neonProgressIndicator(
                  color: AppTheme.neonBlue,
                  size: 60.0,
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  _buildChatTabs(),
                  Expanded(
                    child:
                        _currentChat == null
                            ? Center(
                              child: SizedBox(
                                width: 300,
                                child: AppTheme.neonContainer(
                                  borderColor: AppTheme.neonPurple,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 48,
                                        color: AppTheme.neonPurple.withAlpha(
                                          153,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ВЫБЕРИТЕ ЧАТ',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.neonTextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          intensity: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            : _buildChatMessages(),
                  ),
                  if (_currentChat != null) _buildSuggestions(),
                  _buildMessageInput(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Строка состояния игры
  Widget _buildGameStatusBar() {
    if (_gameState == null) return const SizedBox.shrink();

    final status = _gameState['status'] as String? ?? 'waiting';
    String statusText;
    Color statusColor;

    switch (status) {
      case 'waiting':
        statusText = 'ОЖИДАНИЕ ИГРОКОВ';
        statusColor = AppTheme.neonBlue;
        break;
      case 'playing':
        statusText = 'ИГРА ИДЕТ';
        statusColor = AppTheme.neonGreen;
        break;
      case 'finished':
        statusText = 'ИГРА ЗАВЕРШЕНА';
        statusColor = AppTheme.neonPurple;
        break;
      default:
        statusText = 'СТАТУС НЕИЗВЕСТЕН';
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: statusColor, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(40),
            blurRadius: 8.0,
            spreadRadius: 1.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: AppTheme.neonShadow(statusColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: AppTheme.neonTextStyle(color: statusColor, fontSize: 14.0),
          ),
          const Spacer(),
          if (status == 'waiting' && _isPlayerHost())
            AppTheme.neonButton(
              text: 'НАЧАТЬ ИГРУ',
              onPressed: _startGame,
              color: AppTheme.neonGreen,
              width: 140,
            ),
          if (status == 'finished' && _isPlayerHost())
            AppTheme.neonButton(
              text: 'НАЧАТЬ ЗАНОВО',
              onPressed: _restartGame,
              color: AppTheme.neonGreen,
              width: 160,
            ),
        ],
      ),
    );
  }

  // Проверка, является ли текущий игрок хостом
  bool _isPlayerHost() {
    if (_gameState == null || _currentUserId == null) return false;

    final hostId = _gameState['game']?['hostId'];
    return hostId == _currentUserId;
  }

  // Начать игру
  Future<void> _startGame() async {
    try {
      await context.read<GameplayCubit>().startGame();
      await _loadGameState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при запуске игры: $e')));
      }
    }
  }

  // Перезапустить игру
  Future<void> _restartGame() async {
    try {
      await context.read<GameplayCubit>().restartGame();
      await _loadGameState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при перезапуске игры: $e')),
        );
      }
    }
  }

  // Вкладки для разных чатов
  Widget _buildChatTabs() {
    if (_gameState == null) return const SizedBox.shrink();

    final tabs = <Widget>[];
    final tabColors = [
      AppTheme.neonBlue,
      AppTheme.neonGreen,
      AppTheme.neonPurple,
      AppTheme.neonPink,
    ];

    // Добавляем вкладку общего чата
    tabs.add(_buildTabItem('ОБЩИЙ', 0, tabColors[0]));

    // Добавляем вкладки для индивидуальных чатов игроков
    final playerChats = _gameState['playerChats'] as List?;
    if (playerChats != null) {
      for (int i = 0; i < playerChats.length; i++) {
        final playerChat = playerChats[i];
        final playerName =
            playerChat['playerName'] as String? ?? 'Игрок ${i + 1}';
        tabs.add(
          _buildTabItem(
            playerName.toUpperCase(),
            i + 1,
            tabColors[(i + 1) % tabColors.length],
          ),
        );
      }
    }

    // Добавляем вкладки для чатов советов
    final adviceChats = _gameState['adviceChats'] as List?;
    if (adviceChats != null) {
      final playerChatsCount = playerChats?.length ?? 0;
      for (int i = 0; i < adviceChats.length; i++) {
        final adviceChat = adviceChats[i];
        final adviceTitle = adviceChat['title'] as String? ?? 'Совет ${i + 1}';
        tabs.add(
          _buildTabItem(
            adviceTitle.toUpperCase(),
            i + 1 + playerChatsCount,
            tabColors[(i + 1 + playerChatsCount) % tabColors.length],
          ),
        );
      }
    }

    return Container(
      color: AppTheme.darkAccent,
      height: 50,
      child: ListView(scrollDirection: Axis.horizontal, children: tabs),
    );
  }

  Widget _buildTabItem(String text, int index, Color color) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () => _loadChat(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient:
              isSelected
                  ? LinearGradient(
                    colors: [color, color.withAlpha(100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          border: Border.all(
            color: isSelected ? color : color.withAlpha(100),
            width: 1.5,
          ),
          boxShadow: isSelected ? AppTheme.neonShadow(color) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Сообщения чата
  Widget _buildChatMessages() {
    if (_currentChat == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black87,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: _currentChat!.messages.length,
        itemBuilder: (context, index) {
          final message = _currentChat!.messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  // Отдельный пузырь сообщения
  Widget _buildMessageBubble(Message message) {
    final isCurrentUser = message.senderId == _currentUserId;

    Color bubbleColor;
    BorderRadius borderRadius;

    if (message.sender.type == 'system') {
      // Системное сообщение
      bubbleColor = AppTheme.darkAccent;
      borderRadius = BorderRadius.circular(10);
    } else if (message.sender.type == 'assistant') {
      // Сообщение от ИИ ассистента
      bubbleColor = AppTheme.neonPurple.withAlpha(40);
      borderRadius = BorderRadius.circular(16);
    } else if (isCurrentUser) {
      // Сообщение текущего пользователя
      bubbleColor = AppTheme.neonBlue.withAlpha(40);
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      // Сообщение другого игрока
      bubbleColor = AppTheme.neonGreen.withAlpha(40);
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser && message.sender.type == 'user')
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkSurface,
                boxShadow: AppTheme.neonShadow(AppTheme.neonGreen),
              ),
              child: Center(
                child: Text(
                  message.sender.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          if (message.sender.type == 'assistant')
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkSurface,
                boxShadow: AppTheme.neonShadow(AppTheme.neonPurple),
              ),
              child: Center(
                child: Icon(
                  Icons.smart_toy,
                  size: 16,
                  color: AppTheme.neonPurple,
                ),
              ),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color:
                      message.sender.type == 'system'
                          ? Colors.grey
                          : message.sender.type == 'assistant'
                          ? AppTheme.neonPurple
                          : isCurrentUser
                          ? AppTheme.neonBlue
                          : AppTheme.neonGreen,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((!isCurrentUser && message.sender.type == 'user') ||
                      message.sender.type == 'system')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender.name,
                        style: TextStyle(
                          color:
                              message.sender.type == 'system'
                                  ? Colors.grey
                                  : AppTheme.neonGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color:
                          message.sender.type == 'system'
                              ? Colors.grey
                              : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isCurrentUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkSurface,
                boxShadow: AppTheme.neonShadow(AppTheme.neonBlue),
              ),
              child: Center(
                child: Text(
                  message.sender.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.neonBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Блок с подсказками
  Widget _buildSuggestions() {
    final suggestions = _currentChat?.suggestions ?? [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            suggestions.map((suggestion) {
              return GestureDetector(
                onTap: () => _selectSuggestion(suggestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkAccent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.neonGreen, width: 1),
                    boxShadow: AppTheme.neonShadow(
                      AppTheme.neonGreen.withAlpha(100),
                    ),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(color: AppTheme.neonGreen),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // Поле ввода сообщения
  Widget _buildMessageInput() {
    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neonBlue, width: 1.5),
                boxShadow: AppTheme.neonShadow(AppTheme.neonBlue.withAlpha(80)),
                color: Colors.black45,
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppTheme.neonShadow(AppTheme.neonGreen),
            ),
            child:
                _isSending
                    ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.neonGreen,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : IconButton(
                      icon: Icon(Icons.send, color: AppTheme.neonGreen),
                      onPressed: _sendMessage,
                    ),
          ),
        ],
      ),
    );
  }
}
