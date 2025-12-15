import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';

/// Интерфейс для сервиса игрового процесса
abstract class GameplayService {
  /// Получить текущее состояние игры
  Future<dynamic> getGameState({int? gameId});

  /// Получить сегмент чата
  Future<ChatSegment> getChatSegment(
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
    int? gameId,
  });

  /// Отправить сообщение в чат
  Future<Message> sendMessage(
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
    int? gameId,
  });

  /// Выгнать игрока
  Future<Player> kickPlayer(int playerId, {int? gameId});

  /// Сделать игрока хостом
  Future<Player> promotePlayer(int playerId, {int? gameId});

  /// Отметить, что игрок готов
  Future<Player> setReady(bool isReady, {int? gameId});

  /// Начать игру
  Future<Game> startGame({int? gameId, bool force = false});

  /// Перезапустить игру
  Future<Game> restartGame({int? gameId});
}
