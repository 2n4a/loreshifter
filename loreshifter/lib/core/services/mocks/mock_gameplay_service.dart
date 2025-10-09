import 'package:loreshifter/core/models/chat.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/message.dart';
import 'package:loreshifter/core/models/player.dart';
import 'package:loreshifter/core/models/user.dart';
import 'package:loreshifter/core/services/base_service.dart';

/// Заглушка для сервиса игрового процесса
class MockGameplayService extends BaseService {
  MockGameplayService({required super.apiClient});

  // ID текущего игрока (для демо это всегда 1)
  final int _currentUserId = 1;

  // ID текущей игры
  int? _currentGameId;

  // Фиктивная игра
  Game _createMockGame() {
    final gameId = _currentGameId ?? 1;

    return Game(
      id: gameId,
      code: "GAME${gameId.toString().padLeft(3, '0')}",
      public: true,
      name: "Тестовая игра $gameId",
      world: _createMockWorld(gameId % 3 + 1),
      hostId: 1, // Текущий пользователь - хост
      players: _createMockPlayers(),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      maxPlayers: 4,
      status: GameStatus.playing,
    );
  }

  // Создать фиктивных игроков
  List<Player> _createMockPlayers() {
    return [
      Player(
        user: User(id: 1, name: "Тестовый пользователь"),
        isReady: true,
        isHost: true,
        isSpectator: false,
      ),
      Player(
        user: User(id: 2, name: "Игрок 2"),
        isReady: true,
        isHost: false,
        isSpectator: false,
      ),
      Player(
        user: User(id: 3, name: "Игрок 3"),
        isReady: true,
        isHost: false,
        isSpectator: false,
      ),
    ];
  }

  // Создать фиктивный мир
  dynamic _createMockWorld(int worldId) {
    return {
      "id": worldId,
      "name": "Тестовый мир $worldId",
      "public": true,
      "createdAt": DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      "lastUpdatedAt": DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      "owner": {
        "id": 1,
        "name": "Тестовый пользователь",
      },
      "description": "Это описание тестового мира $worldId."
    };
  }

  // Создать фиктивные сообщения для чата
  List<Message> _createMockMessages(int chatId) {
    final now = DateTime.now();

    return [
      Message(
        id: chatId * 100 + 1,
        chatId: chatId,
        kind: MessageKind.system,
        text: "Добро пожаловать в игру!",
        sentAt: now.subtract(const Duration(minutes: 10)),
      ),
      Message(
        id: chatId * 100 + 2,
        chatId: chatId,
        senderId: 1,
        kind: MessageKind.player,
        text: "Привет всем!",
        sentAt: now.subtract(const Duration(minutes: 8)),
      ),
      Message(
        id: chatId * 100 + 3,
        chatId: chatId,
        senderId: 2,
        kind: MessageKind.player,
        text: "Приветствую!",
        sentAt: now.subtract(const Duration(minutes: 7)),
      ),
      Message(
        id: chatId * 100 + 4,
        chatId: chatId,
        kind: MessageKind.generalInfo,
        text: "Вы находитесь в таверне 'Пьяный гоблин'",
        sentAt: now.subtract(const Duration(minutes: 6)),
      ),
      Message(
        id: chatId * 100 + 5,
        chatId: chatId,
        senderId: 3,
        kind: MessageKind.player,
        text: "Что будем делать дальше?",
        sentAt: now.subtract(const Duration(minutes: 5)),
      ),
      Message(
        id: chatId * 100 + 6,
        chatId: chatId,
        senderId: 1,
        kind: MessageKind.player,
        text: "Давайте исследовать окрестности",
        sentAt: now.subtract(const Duration(minutes: 4)),
      ),
      Message(
        id: chatId * 100 + 7,
        chatId: chatId,
        kind: MessageKind.publicInfo,
        text: "Группа выходит из таверны и направляется в сторону тёмного леса",
        sentAt: now.subtract(const Duration(minutes: 3)),
      ),
      Message(
        id: chatId * 100 + 8,
        chatId: chatId,
        kind: MessageKind.privateInfo,
        text: "Вы замечаете следы на земле, ведущие в глубь леса",
        sentAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  // Создать фиктивный чат
  ChatSegment _createMockChat(int chatId, {int? chatOwner}) {
    return ChatSegment(
      chatId: chatId,
      chatOwner: chatOwner,
      messages: _createMockMessages(chatId),
      previousId: null,
      nextId: null,
      suggestions: [
        "Пойти по следам",
        "Вернуться в таверну",
        "Осмотреть окрестности",
        "Поговорить с группой"
      ],
      interface: ChatInterface(
        type: ChatInterfaceType.full,
      ),
    );
  }

  // Получить текущее состояние игры
  Future<dynamic> getGameState() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final game = _createMockGame();
    _currentGameId = game.id;

    // Создаём моковое состояние игры
    final gameState = {
      "game": game,
      "status": "playing",
      "playerChats": [
        _createMockChat(1, chatOwner: 1),
        _createMockChat(2, chatOwner: 2),
        _createMockChat(3, chatOwner: 3),
      ],
      "adviceChats": [
        _createMockChat(4, chatOwner: 1),
        _createMockChat(5, chatOwner: 2),
        _createMockChat(6, chatOwner: 3),
      ],
      "gameChat": _createMockChat(7),
    };

    return gameState;
  }

  // Получить сегмент чата
  Future<ChatSegment> getChatSegment(
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Создаём фиктивный чат в зависимости от ID
    return _createMockChat(chatId,
      chatOwner: chatId >= 1 && chatId <= 3 ? chatId : null);
  }

  // Отправить сообщение в чат
  Future<Message> sendMessage(
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    // Создаём новое сообщение
    final now = DateTime.now();
    final message = Message(
      id: chatId * 100 + 9, // Условно новый ID
      chatId: chatId,
      senderId: _currentUserId,
      kind: MessageKind.player,
      text: text,
      special: special,
      sentAt: now,
      metadata: metadata,
    );

    return message;
  }

  // Выгнать игрока
  Future<Player> kickPlayer(int playerId) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (playerId == _currentUserId) {
      throw Exception('Нельзя выгнать самого себя');
    }

    final player = _createMockPlayers().firstWhere(
      (player) => player.user.id == playerId,
      orElse: () => throw Exception('Игрок с ID $playerId не найден'),
    );

    return player;
  }

  // Сделать игрока хостом
  Future<Player> promotePlayer(int playerId) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (playerId == _currentUserId) {
      throw Exception('Вы уже являетесь хостом');
    }

    final player = _createMockPlayers().firstWhere(
      (player) => player.user.id == playerId,
      orElse: () => throw Exception('Игрок с ID $playerId не найден'),
    );

    return Player(
      user: player.user,
      isReady: player.isReady,
      isHost: true,
      isSpectator: player.isSpectator,
    );
  }

  // Отметить, что игрок готов
  Future<Player> setReady(bool isReady) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final currentPlayer = _createMockPlayers().firstWhere(
      (player) => player.user.id == _currentUserId,
    );

    return Player(
      user: currentPlayer.user,
      isReady: isReady,
      isHost: currentPlayer.isHost,
      isSpectator: currentPlayer.isSpectator,
    );
  }

  // Начать игру
  Future<Game> startGame({int? gameId, bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final game = _createMockGame();

    // Проверяем, готовы ли все игроки
    if (!force) {
      final notReadyPlayers = game.players.where((player) => !player.isReady).toList();
      if (notReadyPlayers.isNotEmpty) {
        throw Exception('Не все игроки готовы');
      }
    }

    // Обновляем статус игры
    return Game(
      id: game.id,
      code: game.code,
      public: game.public,
      name: game.name,
      world: game.world,
      hostId: game.hostId,
      players: game.players,
      createdAt: game.createdAt,
      maxPlayers: game.maxPlayers,
      status: GameStatus.playing,
    );
  }

  // Перезапустить игру
  Future<Game> restartGame() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final game = _createMockGame();

    // Проверяем, что игра завершена
    if (game.status != GameStatus.finished) {
      throw Exception('Игра ещё не завершена');
    }

    // Создаем новую игру с тем же набором игроков
    return Game(
      id: game.id + 100, // Новый ID
      code: "GAME${(game.id + 100).toString().padLeft(3, '0')}",
      public: game.public,
      name: game.name,
      world: game.world,
      hostId: game.hostId,
      players: game.players.map((player) => Player(
        user: player.user,
        isReady: false,
        isHost: player.isHost,
        isSpectator: player.isSpectator,
      )).toList(),
      createdAt: DateTime.now(),
      maxPlayers: game.maxPlayers,
      status: GameStatus.waiting,
    );
  }
}
