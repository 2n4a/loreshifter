import '/features/games/domain/models/game.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/game_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса работы с играми
class GameServiceImpl extends BaseService implements GameService {
  GameServiceImpl({required super.apiClient});

  @override
  Future<List<Game>> getGames({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    String? filter,
  }) async {
    developer.log('GameService: Запрос списка игр');
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (sort != null) 'sort': sort,
      if (order != null) 'order': order,
      if (filter != null) 'filter': filter,
    };

    return apiClient.get<List<Game>>(
      '/game',
      queryParameters: queryParams,
      fromJson: (data) => (data as List)
          .map((e) => Game.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<Game> getGameById(int id) async {
    developer.log('GameService: Запрос игры по ID: $id');
    return apiClient.get<Game>(
      '/game/$id',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> getCurrentGame() async {
    developer.log('GameService: Запрос текущей игры');
    return apiClient.get<Game>(
      '/game/0',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> getGameByCode(String code) async {
    developer.log('GameService: Запрос игры по коду: $code');
    return apiClient.get<Game>(
      '/game/code/$code',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> createGame({
    required int worldId,
    required bool isPublic,
    String? name,
    int? maxPlayers,
  }) async {
    developer.log('GameService: Создание игры');
    return apiClient.post<Game>(
      '/game',
      data: {
        'worldId': worldId,
        'public': isPublic,
        if (name != null) 'name': name,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
      },
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> updateGame({
    required int id,
    bool? isPublic,
    String? name,
    int? hostId,
    int? maxPlayers,
  }) async {
    developer.log('GameService: Обновление игры $id');
    return apiClient.put<Game>(
      '/game/$id',
      data: {
        if (isPublic != null) 'public': isPublic,
        if (name != null) 'name': name,
        if (hostId != null) 'hostId': hostId,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
      },
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> joinGameById(int id, {bool force = false}) async {
    developer.log('GameService: Присоединение к игре $id (force: $force)');
    return apiClient.post<Game>(
      '/game/$id/join',
      queryParameters: {'force': force ? 1 : 0},
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> joinGameByCode(String code, {bool force = false}) async {
    developer.log('GameService: Присоединение к игре по коду $code (force: $force)');
    return apiClient.post<Game>(
      '/game/code/$code/join',
      queryParameters: {'force': force ? 1 : 0},
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> leaveGame({int? gameId}) async {
    developer.log('GameService: Выход из игры');
    int id;
    if (gameId != null) {
      id = gameId;
    } else {
      // Нужно получить текущую игру, чтобы знать ID
      final currentGame = await getCurrentGame();
      id = currentGame.id;
    }
    await apiClient.post<Map<String, dynamic>>(
      '/game/$id/leave',
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }
}

