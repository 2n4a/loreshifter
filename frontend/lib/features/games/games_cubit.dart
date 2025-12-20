import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/games/domain/models/game.dart';
import '/core/services/game_service.dart';

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
    emit(GamesLoading());
    try {
      final games = await _gameService.getGames();
      emit(GamesLoaded(games));
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Загрузить игру по ID
  Future<void> loadGameById(int gameId) async {
    emit(GamesLoading());
    try {
      final game = await _gameService.getGameById(gameId);
      emit(GameLoaded(game));
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Загрузить игру по коду
  Future<void> loadGameByCode(String code) async {
    emit(GamesLoading());
    try {
      final game = await _gameService.getGameByCode(code);
      emit(GameLoaded(game));
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Присоединиться к игре
  Future<void> joinGame({int? gameId, String? code}) async {
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
      emit(GameJoined(game));
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Покинуть игру
  Future<void> leaveGame(int gameId) async {
    emit(GamesLoading());
    try {
      await _gameService.leaveGame(gameId);
      emit(GameLeft());
    } catch (e) {
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
    emit(GamesLoading());
    try {
      final game = await _gameService.createGame(
        worldId: worldId,
        name: name,
        public: public,
        maxPlayers: maxPlayers,
      );
      emit(GameLoaded(game));
      return game;
    } catch (e) {
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
