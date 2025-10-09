import 'package:loreshifter/core/models/chat.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/message.dart';
import 'package:loreshifter/core/models/player.dart';

/// Интерфейс для сервиса игрового процесса
abstract class GameplayService {
  /// Получить текущее состояние игры
  Future<dynamic> getGameState();

  /// Получить сегмент чата
  Future<ChatSegment> getChatSegment(
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  });

  /// Отправить сообщение в чат
  Future<Message> sendMessage(
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  });

  /// Выгнать игрока
  Future<Player> kickPlayer(int playerId);

  /// Сделать игрока хостом
  Future<Player> promotePlayer(int playerId);

  /// Отметить, что игрок готов
  Future<Player> setReady(bool isReady);

  /// Начать игру
  Future<Game> startGame({int? gameId, bool force = false});

  /// Перезапустить игру
  Future<Game> restartGame();
}
