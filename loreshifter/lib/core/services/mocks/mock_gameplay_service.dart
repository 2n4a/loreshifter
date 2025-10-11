import 'package:loreshifter/core/models/chat.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/message.dart';
import 'package:loreshifter/core/models/player.dart';
import 'package:loreshifter/core/models/user.dart';
import 'package:loreshifter/core/services/interfaces/gameplay_service_interface.dart';

import '../../models/world.dart';

/// Простая мок-реализация GameplayService
class MockGameplayService implements GameplayService {
  // Базовые тестовые данные
  final User _currentUser = User(id: 1, name: 'Вы');
  final User _otherUser = User(id: 2, name: 'Другой игрок');
  final User _systemUser = User(id: 0, name: 'Система');

  // Простое состояние игры
  final Map<String, dynamic> _gameState = {
    'status': 'waiting',
    'gameChat': {'chatId': 1, 'title': 'Основной чат'},
    'playerChats': [
      {'chatId': 2, 'playerName': 'Другой игрок'},
    ],
    'adviceChats': [
      {'chatId': 4, 'title': 'Подсказки'},
    ],
    'game': {'id': 1},
  };

  // Счетчик для генерации ID
  int _messageIdCounter = 100;

  // Начальные данные для чатов
  final Map<int, ChatSegment> _chats = {};

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
  }

  @override
  Future<dynamic> getGameState() async {
    print('DEBUG: MockGameplayService.getGameState()');
    await Future.delayed(Duration(milliseconds: 300));
    return _gameState;
  }

  @override
  Future<ChatSegment> getChatSegment(
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  }) async {
    print('DEBUG: MockGameplayService.getChatSegment(chatId: $chatId)');

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

    return _chats[chatId]!;
  }

  @override
  Future<Message> sendMessage(
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    print(
      'DEBUG: MockGameplayService.sendMessage(chatId: $chatId, text: $text)',
    );

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
      await getChatSegment(chatId);
    }
    _chats[chatId]!.messages.add(message);

    // Добавляем ответ для основного чата
    if (chatId == 1) {
      _addAssistantResponse(chatId);
    }

    return message;
  }

  void _addAssistantResponse(int chatId) {
    Future.delayed(Duration(seconds: 2), () {
      final assistantMessage = Message(
        id: _messageIdCounter++,
        chatId: chatId,
        senderId: 999,
        // ID для ассистента
        text: 'Я получил ваше сообщение. Ожидаю начала игры.',
        kind: MessageKind.generalInfo,
        sentAt: DateTime.now(),
      );

      _chats[chatId]!.messages.add(assistantMessage);
    });
  }

  @override
  Future<Player> kickPlayer(int playerId) async {
    print('DEBUG: MockGameplayService.kickPlayer(playerId: $playerId)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _otherUser,
      isReady: false,
      isHost: false,
      isSpectator: true,
    );
  }

  @override
  Future<Player> promotePlayer(int playerId) async {
    print('DEBUG: MockGameplayService.promotePlayer(playerId: $playerId)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _otherUser,
      isReady: true,
      isHost: true,
      isSpectator: false,
    );
  }

  @override
  Future<Player> setReady(bool isReady) async {
    print('DEBUG: MockGameplayService.setReady(isReady: $isReady)');

    await Future.delayed(Duration(milliseconds: 300));

    return Player(
      user: _currentUser,
      isReady: isReady,
      isHost: true,
      isSpectator: false,
    );
  }

  @override
  Future<Game> startGame({int? gameId, bool force = false}) async {
    print('DEBUG: MockGameplayService.startGame(force: $force)');

    await Future.delayed(Duration(milliseconds: 500));

    // Обновляем статус игры
    _gameState['status'] = 'playing';

    // Добавляем системное сообщение
    final newMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _systemUser.id,
      text: 'Игра началась! Удачи всем участникам.',
      kind: MessageKind.system,
      sentAt: DateTime.now(),
    );

    _chats[1]!.messages.add(newMessage);

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
        type: WorldType.fantasy,
        rating: 5,
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
  Future<Game> restartGame() async {
    print('DEBUG: MockGameplayService.restartGame()');

    await Future.delayed(Duration(milliseconds: 500));

    // Обновляем статус игры
    _gameState['status'] = 'waiting';

    // Очищаем сообщения в основном чате
    _chats[1]?.messages.clear();

    // Добавляем системное сообщение
    final newMessage = Message(
      id: _messageIdCounter++,
      chatId: 1,
      senderId: _systemUser.id,
      text: 'Игра перезапущена. Ожидаем готовности игроков.',
      kind: MessageKind.system,
      sentAt: DateTime.now(),
    );

    _chats[1]!.messages.add(newMessage);

    // Возвращаем объект игры
    return Game(
      id: 2,
      // Новый ID игры
      code: 'DEF456',
      public: true,
      name: 'Тестовая игра (перезапуск)',
      world: World(
        id: 1,
        name: 'Тестовый мир',
        public: true,
        createdAt: DateTime.now().subtract(Duration(days: 10)),
        lastUpdatedAt: DateTime.now(),
        owner: _currentUser,
        type: WorldType.fantasy,
        rating: 5,
        data: {},
      ),
      hostId: _currentUser.id,
      players: [
        Player(
          user: _currentUser,
          isReady: false,
          isHost: true,
          isSpectator: false,
        ),
        Player(
          user: _otherUser,
          isReady: false,
          isHost: false,
          isSpectator: false,
        ),
      ],
      createdAt: DateTime.now(),
      maxPlayers: 4,
      status: GameStatus.waiting,
    );
  }
}
