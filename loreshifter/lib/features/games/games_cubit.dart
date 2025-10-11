import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/services/game_service.dart';

// События для работы с играми
abstract class GamesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGamesRequested extends GamesEvent {}

class LoadGameByIdRequested extends GamesEvent {
  final int gameId;

  LoadGameByIdRequested(this.gameId);

  @override
  List<Object?> get props => [gameId];
}

class LoadGameByCodeRequested extends GamesEvent {
  final String code;

  LoadGameByCodeRequested(this.code);

  @override
  List<Object?> get props => [code];
}

class JoinGameRequested extends GamesEvent {
  final int? gameId;
  final String? code;
  final bool force;

  JoinGameRequested({this.gameId, this.code, this.force = false});

  @override
  List<Object?> get props => [gameId, code, force];
}

class LeaveGameRequested extends GamesEvent {}

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
  Future<void> joinGame({int? gameId, String? code, bool force = false}) async {
    emit(GamesLoading());
    try {
      Game game;
      if (gameId != null) {
        game = await _gameService.joinGameById(gameId, force: force);
      } else if (code != null) {
        game = await _gameService.joinGameByCode(code, force: force);
      } else {
        throw Exception('Необходимо указать gameId или code');
      }
      emit(GameJoined(game));
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Покинуть игру
  Future<void> leaveGame() async {
    emit(GamesLoading());
    try {
      await _gameService.leaveGame();
      emit(GameLeft());
    } catch (e) {
      emit(GamesFailure(e.toString()));
    }
  }

  // Создать новую игру
  Future<Game> createGame({
    required int worldId,
    required String name,
    required bool isPublic,
    required int maxPlayers,
  }) async {
    emit(GamesLoading());
    try {
      final game = await _gameService.createGame(
        worldId: worldId,
        name: name,
        isPublic: isPublic,
        maxPlayers: maxPlayers,
      );
      emit(GameLoaded(game));
      return game;
    } catch (e) {
      emit(GamesFailure(e.toString()));
      throw e;
    }
  }
}
