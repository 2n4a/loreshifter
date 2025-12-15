import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса игрового процесса
class GameplayServiceImpl extends BaseService implements GameplayService {
  int? _currentGameId;

  GameplayServiceImpl({required super.apiClient});

  /// Установить текущую игру
  void setCurrentGameId(int gameId) {
    _currentGameId = gameId;
    developer.log('GameplayService: Установлена текущая игра: $gameId');
  }

  /// Получить текущий gameId или выбросить исключение
  int _getGameId({int? gameId}) {
    final id = gameId ?? _currentGameId;
    if (id == null) {
      throw Exception('Game ID не установлен. Используйте setCurrentGameId() или передайте gameId в метод.');
    }
    return id;
  }

  @override
  Future<dynamic> getGameState({int? gameId}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Запрос состояния игры $id');
    return apiClient.get<Map<String, dynamic>>(
      '/game/$id/state',
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }

  @override
  Future<ChatSegment> getChatSegment(
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
    int? gameId,
  }) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Запрос сегмента чата $chatId в игре $id');
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };

    return apiClient.get<ChatSegment>(
      '/game/$id/chat/$chatId',
      queryParameters: queryParams,
      fromJson: (data) => ChatSegment.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Message> sendMessage(
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
    int? gameId,
  }) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Отправка сообщения в чат $chatId игры $id');
    return apiClient.post<Message>(
      '/game/$id/chat/$chatId/send',
      data: {
        'text': text,
        if (special != null) 'special': special,
        if (metadata != null) 'metadata': metadata,
      },
      fromJson: (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> kickPlayer(int playerId, {int? gameId}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Исключение игрока $playerId из игры $id');
    return apiClient.post<Player>(
      '/game/$id/kick',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> promotePlayer(int playerId, {int? gameId}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Назначение игрока $playerId хостом игры $id');
    return apiClient.post<Player>(
      '/game/$id/promote',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> setReady(bool isReady, {int? gameId}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Установка статуса готовности в игре $id: $isReady');
    return apiClient.post<Player>(
      '/game/$id/ready',
      data: {'isReady': isReady},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> startGame({int? gameId, bool force = false}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Запуск игры $id (force: $force)');
    return apiClient.post<Game>(
      '/game/$id/start',
      queryParameters: {'force': force ? 1 : 0},
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> restartGame({int? gameId}) async {
    final id = _getGameId(gameId: gameId);
    developer.log('GameplayService: Перезапуск игры $id');
    return apiClient.post<Game>(
      '/game/$id/restart',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }
}

