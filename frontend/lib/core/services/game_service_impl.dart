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
    bool? public,
    bool? joined,
  }) async {
    developer.log('GameService: Запрос списка игр');
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (sort != null) 'sort': sort,
      if (order != null) 'order': order,
      if (filter != null) 'filter': filter,
      if (public != null) 'public': public,
      if (joined != null) 'joined': joined,
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
    required bool public,
    String? name,
    int? maxPlayers,
  }) async {
    developer.log('GameService: Создание игры');
    return apiClient.post<Game>(
      '/game',
      data: {
        'world_id': worldId,
        'public': public,
        if (name != null) 'name': name,
        if (maxPlayers != null) 'max_players': maxPlayers,
      },
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> updateGame({
    required int id,
    bool? public,
    String? name,
    int? hostId,
    int? maxPlayers,
  }) async {
    developer.log('GameService: Обновление игры $id');
    return apiClient.put<Game>(
      '/game/$id',
      data: {
        if (public != null) 'public': public,
        if (name != null) 'name': name,
        if (hostId != null) 'host_id': hostId,
        if (maxPlayers != null) 'max_players': maxPlayers,
      },
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> joinGameById(int id) async {
    developer.log('GameService: Присоединение к игре $id');
    return apiClient.post<Game>(
      '/game/$id/join',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> joinGameByCode(String code) async {
    developer.log('GameService: Присоединение к игре по коду $code');
    return apiClient.post<Game>(
      '/game/code/$code/join',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> leaveGame(int gameId) async {
    developer.log('GameService: Выход из игры $gameId');
    await apiClient.post<Map<String, dynamic>>(
      '/game/$gameId/leave',
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }
}

