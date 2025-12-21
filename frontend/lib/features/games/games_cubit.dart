import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/games/domain/models/game.dart';
import '/core/services/game_service.dart';
import 'dart:developer' as developer;

// Состояния для работы с играми
abstract class GamesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GamesInitial extends GamesState {}

class GamesLoading extends GamesState {}

class GamesLoaded extends GamesState {
  final List<Game> games;

  GamesLoaded(this.games);

  @override
  List<Object?> get props => [games];
}

class GameLoaded extends GamesState {
  final Game game;

  GameLoaded(this.game);

  @override
  List<Object?> get props => [game];
}

class GameJoined extends GamesState {
  final Game game;

  GameJoined(this.game);

  @override
  List<Object?> get props => [game];
}

class GameLeft extends GamesState {}

class GamesFailure extends GamesState {
  final String message;

  GamesFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// Кубит для работы с играми
class GamesCubit extends Cubit<GamesState> {
  final GameService _gameService;

  GamesCubit({required GameService gameService})
    : _gameService = gameService,
      super(GamesInitial());

  // Загрузить список всех доступных игр
  Future<void> loadGames() async {
    developer.log('[CUBIT:GAMES] loadGames() started');
    emit(GamesLoading());
    try {
      final games = await _gameService.getGames();
      developer.log('[CUBIT:GAMES] loadGames() -> GamesLoaded(count=${games.length})');
      emit(GamesLoaded(games));
    } catch (e) {
      developer.log('[CUBIT:GAMES] loadGames() -> Error', error: e);
      emit(GamesFailure(e.toString()));
    }
  }

  // Загрузить игру по ID
  Future<void> loadGameById(int gameId) async {
    developer.log('[CUBIT:GAMES] loadGameById($gameId) started');
    emit(GamesLoading());
    try {
      final game = await _gameService.getGameById(gameId);
      developer.log('[CUBIT:GAMES] loadGameById() -> GameLoaded(id=${game.id}, name=${game.name})');
      emit(GameLoaded(game));
    } catch (e) {
      developer.log('[CUBIT:GAMES] loadGameById() -> Error', error: e);
      emit(GamesFailure(e.toString()));
    }
  }

  // Загрузить игру по коду
  Future<void> loadGameByCode(String code) async {
    developer.log('[CUBIT:GAMES] loadGameByCode($code) started');
    emit(GamesLoading());
    try {
      final game = await _gameService.getGameByCode(code);
      developer.log('[CUBIT:GAMES] loadGameByCode() -> GameLoaded(id=${game.id})');
      emit(GameLoaded(game));
    } catch (e) {
      developer.log('[CUBIT:GAMES] loadGameByCode() -> Error', error: e);
      emit(GamesFailure(e.toString()));
    }
  }

  // Присоединиться к игре
  Future<void> joinGame({int? gameId, String? code}) async {
    developer.log('[CUBIT:GAMES] joinGame(gameId=$gameId, code=$code) started');
    emit(GamesLoading());
    try {
      Game game;
      if (gameId != null) {
        game = await _gameService.joinGameById(gameId);
      } else if (code != null) {
        game = await _gameService.joinGameByCode(code);
      } else {
        throw Exception('Необходимо указать gameId или code');
      }
      developer.log('[CUBIT:GAMES] joinGame() -> GameJoined(id=${game.id})');
      emit(GameJoined(game));
    } catch (e) {
      developer.log('[CUBIT:GAMES] joinGame() -> Error', error: e);
      emit(GamesFailure(e.toString()));
    }
  }

  // Покинуть игру
  Future<void> leaveGame(int gameId) async {
    developer.log('[CUBIT:GAMES] leaveGame($gameId) started');
    emit(GamesLoading());
    try {
      await _gameService.leaveGame(gameId);
      developer.log('[CUBIT:GAMES] leaveGame() -> GameLeft');
      emit(GameLeft());
    } catch (e) {
      developer.log('[CUBIT:GAMES] leaveGame() -> Error', error: e);
      emit(GamesFailure(e.toString()));
    }
  }

  // Создать новую игру
  Future<Game> createGame({
    required int worldId,
    required String name,
    required bool public,
    required int maxPlayers,
  }) async {
    developer.log('[CUBIT:GAMES] createGame(worldId=$worldId, name=$name) started');
    emit(GamesLoading());
    try {
      final game = await _gameService.createGame(
        worldId: worldId,
        name: name,
        public: public,
        maxPlayers: maxPlayers,
      );
      developer.log('[CUBIT:GAMES] createGame() -> GameLoaded(id=${game.id})');
      emit(GameLoaded(game));
      return game;
    } catch (e) {
      developer.log('[CUBIT:GAMES] createGame() -> Error', error: e);
      emit(GamesFailure(e.toString()));
      rethrow;
    }
  }

  // Обновить игру
  Future<Game> updateGame({
    required int id,
    bool? public,
    String? name,
    int? hostId,
    int? maxPlayers,
  }) async {
    emit(GamesLoading());
    try {
      final game = await _gameService.updateGame(
        id: id,
        public: public,
        name: name,
        hostId: hostId,
        maxPlayers: maxPlayers,
      );
      emit(GameLoaded(game));
      return game;
    } catch (e) {
      emit(GamesFailure(e.toString()));
      rethrow;
    }
  }
}
