import 'dart:async';
import 'package:flutter/foundation.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/auth/domain/models/user.dart';
import '/features/worlds/domain/models/world.dart';
import '/features/chat/domain/models/game_state.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';

/// Простая мок-реализация GameplayService
class MockGameplayService implements GameplayService {
  // Базовые тестовые данные
  final User _currentUser = User(id: 1, name: 'Вы');
  final User _otherUser = User(id: 2, name: 'Другой игрок');
  final User _systemUser = User(id: 0, name: 'Система');
  final User _assistantUser = User(id: 999, name: 'ИИ Мастер');

  // Простое состояние игры - must match GameState structure
  final Map<String, dynamic> _gameState = {
    'status': 'waiting',
    'game': {
      'id': 1,
      'code': 'TEST123',
      'public': true,
      'name': 'Тестовая игра',
      'world': {
        'id': 1,
        'name': 'Тестовый мир',
        'owner': {'id': 1, 'name': 'Вы', 'created_at': DateTime.now().toIso8601String(), 'deleted': false},
        'public': true,
        'description': 'Описание тестового мира',
        'created_at': DateTime.now().toIso8601String(),
        'last_updated_at': DateTime.now().toIso8601String(),
        'deleted': false,
      },
      'host_id': 1,
      'players': [
        {
          'user': {'id': 1, 'name': 'Вы', 'created_at': DateTime.now().toIso8601String(), 'deleted': false},
          'is_ready': false,
          'is_host': true,
          'is_spectator': false,
        },
      ],
      'created_at': DateTime.now().toIso8601String(),
      'max_players': 4,
      'status': 'waiting',
    },
    'character_creation_chat': null,
    'game_chat': null,
    'player_chats': [],
    'advice_chats': [],
  };

  // Счетчик для генерации ID
  int _messageIdCounter = 100;
  int _turnNumber = 0;
  bool _waitingForPlayerAction = false;
  int _bossHealth = 100;
  int _playerHealth = 100;

  // Начальные данные для чатов
  final Map<int, ChatSegment> _chats = {};
  
  final List<Map<String, dynamic>> _gameTurns = [];
  
  /// Вспомогательный метод для добавления сообщения в чат
  void _addMessageToChat(int chatId, Message message) {
    if (!_chats.containsKey(chatId)) {
      _chats[chatId] = ChatSegment(
        chatId: chatId,
        messages: [message],
        suggestions: [],
        interface: ChatInterface(type: ChatInterfaceType.full),
      );
      return;
    }
    
    final currentChat = _chats[chatId]!;
    final updatedMessages = List<Message>.from(currentChat.messages)..add(message);
    _chats[chatId] = ChatSegment(
      chatId: currentChat.chatId,
      messages: updatedMessages,
      suggestions: currentChat.suggestions,
      interface: currentChat.interface,
      previousId: currentChat.previousId,
      nextId: currentChat.nextId,
      chatOwner: currentChat.chatOwner,
    );
  }
  
  /// Вспомогательный метод для обновления интерфейса чата
  void _updateChatInterface(int chatId, ChatInterface newInterface) {
    if (!_chats.containsKey(chatId)) return;
    
    final currentChat = _chats[chatId]!;
    _chats[chatId] = ChatSegment(
      chatId: currentChat.chatId,
      messages: currentChat.messages,
      suggestions: currentChat.suggestions,
      interface: newInterface,
      previousId: currentChat.previousId,
      nextId: currentChat.nextId,
      chatOwner: currentChat.chatOwner,
    );
  }
  
  /// Вспомогательный метод для обновления предложений в чате
  void _updateChatSuggestions(int chatId, List<String> newSuggestions, {ChatInterface? newInterface}) {
    if (!_chats.containsKey(chatId)) return;
    
    final currentChat = _chats[chatId]!;
    _chats[chatId] = ChatSegment(
      chatId: currentChat.chatId,
      messages: currentChat.messages,
      suggestions: newSuggestions,
      interface: newInterface ?? currentChat.interface,
      previousId: currentChat.previousId,
      nextId: currentChat.nextId,
      chatOwner: currentChat.chatOwner,
    );
  }

  MockGameplayService() {
    // Инициализируем основной чат с приветственным сообщением
    _chats[1] = ChatSegment(
      chatId: 1,
      messages: [
        Message(
          id: 1,
          chatId: 1,
          senderId: 0,
          text: 'Добро пожаловать в игру!',
          kind: MessageKind.system,
          sentAt: DateTime.now().subtract(Duration(minutes: 5)),
        ),
      ],
      suggestions: ['Привет всем!', 'Готов играть!'],
      interface: ChatInterface(type: ChatInterfaceType.full),
    );
    _gameState['game_chat'] = _chats[1]!.toJson();
  }

  @override
  Future<GameState> getGameState(int gameId) async {
    debugPrint('DEBUG: MockGameplayService.getGameState(gameId: $gameId)');
    await Future.delayed(Duration(milliseconds: 300));
    if (_chats.containsKey(1)) {
      _gameState['game_chat'] = _chats[1]!.toJson();
    }
    if (_chats.containsKey(2)) {
      _gameState['player_chats'] = [_chats[2]!.toJson()];
    }
    // Mock implementation returns a structured GameState
    return GameState.fromJson(_gameState);
  }

  @override
  Future<ChatSegment> getChatSegment(
    int gameId,
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  }) async {
    debugPrint('DEBUG: MockGameplayService.getChatSegment(chatId: $chatId, before: $before, after: $after, limit: $limit)');

    await Future.delayed(Duration(milliseconds: 300));

    // Если чат не существует, создаем пустой
    if (!_chats.containsKey(chatId)) {
      _chats[chatId] = ChatSegment(
        chatId: chatId,
        messages: [],
        suggestions: ['Привет!', 'Как дела?'],
        interface: ChatInterface(type: ChatInterfaceType.full),
      );
    }

    final base = _chats[chatId]!;
    final all = List<Message>.from(base.messages)
      ..sort((a, b) => a.id.compareTo(b.id));

    List<Message> window;
    if (before != null) {
      final older = all.where((m) => m.id < before).toList();
      window = older.length > limit ? older.sublist(older.length - limit) : older;
    } else if (after != null) {
      final newer = all.where((m) => m.id > after).toList();
      window = newer.length > limit ? newer.sublist(0, limit) : newer;
    } else {
      window = all.length > limit ? all.sublist(all.length - limit) : all;
    }

    int? previousId;
    int? nextId;
    if (window.isNotEmpty) {
      final hasOlder = all.first.id < window.first.id;
      final hasNewer = all.last.id > window.last.id;
      previousId = hasOlder ? window.first.id : null;
      nextId = hasNewer ? window.last.id : null;
    }

    return ChatSegment(
      chatId: chatId,
      messages: window,
      previousId: previousId,
      nextId: nextId,
      suggestions: base.suggestions,
      interface: base.interface,
    );
  }

  @override
  Future<Message> sendMessage(
    int gameId,
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('DEBUG: MockGameplayService.sendMessage(chatId: $chatId, text: $text)');

    await Future.delayed(Duration(milliseconds: 300));

    final message = Message(
      id: _messageIdCounter++,
      chatId: chatId,
      senderId: _currentUser.id,
      text: text,
      kind: MessageKind.player,
      sentAt: DateTime.now(),
      special: special,
      metadata: metadata,
    );

    // Добавляем сообщение в чат
    if (!_chats.containsKey(chatId)) {
      await getChatSegment(gameId, chatId);
    }
    _addMessageToChat(chatId, message);

    // Обработка действий в зависимости от чата
    if (_gameState['status'] == 'playing') {
      if (chatId == 2) {
        // Действие игрока в его личном чате
        await _handlePlayerAction(text);
      } else if (chatId == 1) {
        // Сообщение в общем чате
        _addGeneralChatResponse(chatId, text);
      }
    } else {
      // В режиме ожидания
      if (chatId == 1) {
        _addAssistantResponse(chatId);
      }
    }

    return message;
  }

  /// Обработка действия игрока в игре
  Future<void> _handlePlayerAction(String actionText) async {
    if (!_waitingForPlayerAction) return;
    
    _waitingForPlayerAction = false;
    
    // Добавляем сообщение о действии в общий чат
    final actionMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _currentUser.id,
      text: '${_currentUser.name}: $actionText',
      kind: MessageKind.player,
      sentAt: DateTime.now(),
      metadata: {'senderName': _currentUser.name},
    );
    _addMessageToChat(1, actionMessage);
    
    // Симулируем задержку обработки
    await Future.delayed(Duration(seconds: 1));
    
    // Генерируем реакцию босса и результат хода
    await _processTurnResolution(actionText);
  }

  /// Обработка разрешения хода
  Future<void> _processTurnResolution(String playerAction) async {
    _turnNumber++;
    
    // Определяем результат на основе действия
    String resolution;
    List<String> nextSuggestions;
    bool isBossAttack = _turnNumber % 2 == 0;
    
    if (playerAction.toLowerCase().contains('атак') || 
        playerAction.toLowerCase().contains('удар') ||
        playerAction.toLowerCase().contains('бью')) {
      // Успешная атака
      final damage = 15 + (DateTime.now().millisecond % 10);
      _bossHealth = (_bossHealth - damage).clamp(0, 100);
      resolution = 'Вы нанесли $damage урона боссу! Здоровье босса: $_bossHealth/100';
      
      if (_bossHealth <= 0) {
        resolution += '\n\n🎉 ПОБЕДА! Босс повержен!';
        _gameState['status'] = 'finished';
        _updateChatInterface(2, ChatInterface(type: ChatInterfaceType.readonly));
      } else {
        nextSuggestions = _getNextActionSuggestions();
      }
    } else if (playerAction.toLowerCase().contains('защит') ||
               playerAction.toLowerCase().contains('блок') ||
               playerAction.toLowerCase().contains('уклон')) {
      // Защита
      final damage = isBossAttack ? 5 : 0;
      _playerHealth = (_playerHealth - damage).clamp(0, 100);
      resolution = damage > 0 
          ? 'Вы частично заблокировали атаку! Получено $damage урона. Ваше здоровье: $_playerHealth/100'
          : 'Вы успешно защитились! Урон не получен.';
      nextSuggestions = _getNextActionSuggestions();
    } else {
      // Другое действие
      resolution = 'Вы выполнили действие: "$playerAction". Босс наблюдает за вами...';
      nextSuggestions = _getNextActionSuggestions();
    }
    
    // Добавляем результат в общий чат
    final resolutionMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _assistantUser.id,
      text: resolution,
      kind: MessageKind.generalInfo,
      sentAt: DateTime.now(),
      metadata: {'senderName': 'ИИ Мастер'},
    );
    _addMessageToChat(1, resolutionMessage);
    
    // Если игра не закончилась, генерируем следующее событие
    if (_gameState['status'] == 'playing' && _bossHealth > 0 && _playerHealth > 0) {
      await Future.delayed(Duration(seconds: 2));
      await _generateNextTurnEvent();
    } else if (_playerHealth <= 0) {
      // Поражение
      final defeatMessage = Message(
        id: _messageIdCounter++,
        chatId: 1,
        senderId: _systemUser.id,
        text: '💀 ПОРАЖЕНИЕ! Вы погибли в битве с боссом.',
        kind: MessageKind.system,
        sentAt: DateTime.now(),
      );
      _addMessageToChat(1, defeatMessage);
      _gameState['status'] = 'finished';
      _updateChatInterface(2, ChatInterface(type: ChatInterfaceType.readonly));
    }
  }

  /// Генерация следующего события от босса
  Future<void> _generateNextTurnEvent() async {
    final events = [
      {
        'title': '⚔️ Босс готовится к атаке!',
        'description': 'Темный лорд поднимает свой меч и готовится нанести мощный удар. У вас есть время, чтобы среагировать!',
        'suggestions': ['Атакую первым!', 'Защищаюсь щитом', 'Уклоняюсь в сторону', 'Использую заклинание защиты'],
      },
      {
        'title': '🔥 Босс использует огненное дыхание!',
        'description': 'Из пасти босса вырывается поток пламени! Нужно срочно что-то предпринять!',
        'suggestions': ['Прыгаю в сторону', 'Использую ледяной щит', 'Атакую в момент зарядки', 'Ищу укрытие'],
      },
      {
        'title': '💀 Босс призывает нежить!',
        'description': 'Вокруг появляются скелеты-воины. Босс отступает, показывая на вас пальцем. "Уничтожьте его!"',
        'suggestions': ['Атакую босса напрямую', 'Сражаюсь со скелетами', 'Использую заклинание массового поражения', 'Бегу к боссу'],
      },
      {
        'title': '⚡ Босс заряжает магию!',
        'description': 'Босс начинает произносить заклинание. Вокруг него собирается темная энергия. Это ваш шанс!',
        'suggestions': ['Прерываю заклинание атакой', 'Готовлю контратаку', 'Защищаюсь магией', 'Использую все силы для удара'],
      },
    ];
    
    final event = events[_turnNumber % events.length];
    
    // Добавляем событие в общий чат
    final eventMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _assistantUser.id,
      text: '${event['title']}\n\n${event['description']}',
      kind: MessageKind.generalInfo,
      sentAt: DateTime.now(),
      metadata: {'senderName': 'ИИ Мастер'},
    );
    _addMessageToChat(1, eventMessage);
    
    // Обновляем чат игрока с новыми предложениями и timed интерфейсом
    if (_chats.containsKey(2)) {
      final deadline = DateTime.now().add(Duration(seconds: 30));
      final currentChat2 = _chats[2]!;
      _chats[2] = ChatSegment(
        chatId: currentChat2.chatId,
        messages: List.from(currentChat2.messages),
        suggestions: (event['suggestions'] as List<String>),
        interface: ChatInterface(
          type: ChatInterfaceType.timed,
          deadline: deadline,
        ),
        previousId: currentChat2.previousId,
        nextId: currentChat2.nextId,
        chatOwner: currentChat2.chatOwner,
      );
      _waitingForPlayerAction = true;
    }
    
    // Если босс атакует, наносим урон
    if (_turnNumber % 2 == 0) {
      await Future.delayed(Duration(seconds: 1));
      final bossDamage = 10 + (DateTime.now().millisecond % 15);
      _playerHealth = (_playerHealth - bossDamage).clamp(0, 100);
      
      final attackMessage = Message(
        id: _messageIdCounter++,
        chatId: 1,
        senderId: _assistantUser.id,
        text: '⚔️ Босс нанес вам $bossDamage урона! Ваше здоровье: $_playerHealth/100',
        kind: MessageKind.generalInfo,
        sentAt: DateTime.now(),
        metadata: {'senderName': 'ИИ Мастер'},
      );
      _addMessageToChat(1, attackMessage);
    }
  }

  /// Генерация первого хода игры
  Future<void> _generateFirstTurn() async {
    if (_gameState['status'] != 'playing') return;
    
    // Добавляем вводное сообщение в общий чат
    final introMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _assistantUser.id,
      text: '''🎮 ИГРА НАЧАЛАСЬ!

Вы стоите в темном подземелье перед огромным боссом - Темным Лордом. 
Его красные глаза сверкают в темноте, а в руках он держит магический меч.

Ваше здоровье: $_playerHealth/100
Здоровье босса: $_bossHealth/100

Босс рычит: "Смелые авантюристы... Вы пришли умирать!"''',
      kind: MessageKind.generalInfo,
      sentAt: DateTime.now(),
      metadata: {'senderName': 'ИИ Мастер'},
    );
    _addMessageToChat(1, introMessage);
    
    // Генерируем первое событие
    await Future.delayed(Duration(seconds: 1));
    await _generateNextTurnEvent();
  }

  List<String> _getNextActionSuggestions() {
    return [
      'Атакую босса',
      'Защищаюсь',
      'Использую заклинание',
      'Изучаю окружение',
    ];
  }

  void _addGeneralChatResponse(int chatId, String text) {
    Future.delayed(Duration(seconds: 1), () {
      final assistantMessage = Message(
        id: _messageIdCounter++,
        chatId: chatId,
        senderId: _assistantUser.id,
        text: 'Понял, записал ваше сообщение.',
        kind: MessageKind.generalInfo,
        sentAt: DateTime.now(),
        metadata: {'senderName': 'ИИ Мастер'},
      );

      if (_chats.containsKey(chatId)) {
        _addMessageToChat(chatId, assistantMessage);
      }
    });
  }

  void _addAssistantResponse(int chatId) {
    Future.delayed(Duration(seconds: 2), () {
      final assistantMessage = Message(
        id: _messageIdCounter++,
        chatId: chatId,
        senderId: _assistantUser.id,
        text: 'Я получил ваше сообщение. Ожидаю начала игры.',
        kind: MessageKind.generalInfo,
        sentAt: DateTime.now(),
        metadata: {'senderName': 'ИИ Мастер'},
      );

      if (_chats.containsKey(chatId)) {
        _addMessageToChat(chatId, assistantMessage);
      }
    });
  }

  @override
  Future<Player> kickPlayer(int gameId, int playerId) async {
    debugPrint('DEBUG: MockGameplayService.kickPlayer(playerId: $playerId)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _otherUser,
      isReady: false,
      isHost: false,
      isSpectator: true,
    );
  }

  @override
  Future<Player> promotePlayer(int gameId, int playerId) async {
    debugPrint('DEBUG: MockGameplayService.promotePlayer(playerId: $playerId)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _otherUser,
      isReady: true,
      isHost: true,
      isSpectator: false,
    );
  }

  @override
  Future<Player> setReady(int gameId, bool isReady) async {
    debugPrint('DEBUG: MockGameplayService.setReady(isReady: $isReady)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _currentUser,
      isReady: isReady,
      isHost: true,
      isSpectator: false,
    );
  }

  @override
  Future<Game> startGame(int gameId, {bool force = false}) async {
    debugPrint('DEBUG: MockGameplayService.startGame(force: $force)');

    await Future.delayed(Duration(milliseconds: 500));

    // Обновляем статус игры
    _gameState['status'] = 'playing';

    // Добавляем системное сообщение
    final newMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _systemUser.id,
      text: 'Игра началась! Удачи всем участникам. Теперь доступны чаты игроков.',
      kind: MessageKind.system,
      sentAt: DateTime.now(),
    );

    _addMessageToChat(1, newMessage);
    
    // Создаем начальные сообщения для чатов игроков
    if (!_chats.containsKey(2)) {
      _chats[2] = ChatSegment(
        chatId: 2,
        messages: [
          Message(
            id: _messageIdCounter++,
            chatId: 2,
            senderId: _assistantUser.id,
            text: 'Добро пожаловать в ваш личный чат! Здесь вы описываете свои действия в игре.\n\nИгра скоро начнется...',
            kind: MessageKind.generalInfo,
            sentAt: DateTime.now(),
            metadata: {'senderName': 'ИИ Мастер'},
          ),
        ],
        suggestions: [],
        interface: ChatInterface(type: ChatInterfaceType.readonly),
      );
    }

    _gameState['player_chats'] = [_chats[2]!.toJson()];
    _gameState['advice_chats'] = [];
    
    // Сбрасываем состояние игры
    _turnNumber = 0;
    _bossHealth = 100;
    _playerHealth = 100;
    _waitingForPlayerAction = false;
    
    // Запускаем первый ход через небольшую задержку
    Future.delayed(Duration(seconds: 2), () {
      _generateFirstTurn();
    });

    // Возвращаем объект игры
    return Game(
      id: gameId ?? 1,
      code: 'ABC123',
      public: true,
      name: 'Тестовая игра',
      world: World(
        id: 1,
        name: 'Тестовый мир',
        public: true,
        createdAt: DateTime.now().subtract(Duration(days: 10)),
        lastUpdatedAt: DateTime.now().subtract(Duration(days: 1)),
        owner: _currentUser,
        data: {},
      ),
      hostId: _currentUser.id,
      players: [
        Player(
          user: _currentUser,
          isReady: true,
          isHost: true,
          isSpectator: false,
        ),
        Player(
          user: _otherUser,
          isReady: true,
          isHost: false,
          isSpectator: false,
        ),
      ],
      createdAt: DateTime.now().subtract(Duration(minutes: 10)),
      maxPlayers: 4,
      status: GameStatus.playing,
    );
  }

  @override
  Future<Game> restartGame(int gameId) async {
    debugPrint('DEBUG: MockGameplayService.restartGame()');
    return startGame(gameId, force: true);
  }

  @override
  Stream<Map<String, dynamic>> connectWebSocket(int gameId) {
    debugPrint('DEBUG: MockGameplayService.connectWebSocket(gameId: $gameId)');
    // Mock WebSocket - just return an empty stream for now
    return Stream<Map<String, dynamic>>.empty();
  }

  @override
  void disconnectWebSocket() {
    debugPrint('DEBUG: MockGameplayService.disconnectWebSocket()');
    // No-op for mock
  }
}
