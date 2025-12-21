import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/chat/domain/models/game_state.dart';

/// Интерфейс для сервиса игрового процесса
abstract class GameplayService {
  /// Получить текущее состояние игры
  Future<GameState> getGameState(int gameId);

  /// Получить сегмент чата
  Future<ChatSegment> getChatSegment(
    int gameId,
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  });

  /// Отправить сообщение в чат
  Future<Message> sendMessage(
    int gameId,
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  });

  /// Выгнать игрока
  Future<Player> kickPlayer(int gameId, int playerId);

  /// Сделать игрока хостом
  Future<Player> promotePlayer(int gameId, int playerId);

  /// Отметить, что игрок готов
  Future<Player> setReady(int gameId, bool isReady);

  /// Начать игру
  Future<Game> startGame(int gameId, {bool force = false});

  /// Подключиться к WebSocket для получения обновлений
  Stream<Map<String, dynamic>> connectWebSocket(int gameId);

  /// Отключиться от WebSocket
  void disconnectWebSocket();
}
