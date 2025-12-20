import '/features/games/domain/models/game.dart';

/// Интерфейс для сервиса работы с играми
abstract class GameService {
  /// Получить список игр
  Future<List<Game>> getGames({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    String? filter,
    bool? public,
    bool? joined,
  });

  /// Получить информацию о игре по ID
  Future<Game> getGameById(int id);

  /// Получить текущую игру
  Future<Game> getCurrentGame();

  /// Получить игру по коду
  Future<Game> getGameByCode(String code);

  /// Создать новую игру
  Future<Game> createGame({
    required int worldId,
    required bool public,
    String? name,
    int? maxPlayers,
  });

  /// Обновить информацию об игре
  Future<Game> updateGame({
    required int id,
    bool? public,
    String? name,
    int? hostId,
    int? maxPlayers,
  });

  /// Присоединиться к игре по ID
  Future<Game> joinGameById(int id);

  /// Присоединиться к игре по коду
  Future<Game> joinGameByCode(String code);

  /// Покинуть игру
  Future<void> leaveGame(int gameId);
}
