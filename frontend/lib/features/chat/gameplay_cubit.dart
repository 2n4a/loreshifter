import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/chat/domain/models/game_state.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';

// Состояния для работы с игровым процессом
abstract class GameplayState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameplayInitial extends GameplayState {}

class GameplayLoading extends GameplayState {}

class GameStateLoaded extends GameplayState {
  final GameState gameState;

  GameStateLoaded(this.gameState);

  @override
  List<Object?> get props => [gameState];
}

class ChatLoaded extends GameplayState {
  final ChatSegment chatSegment;

  ChatLoaded(this.chatSegment);

  @override
  List<Object?> get props => [chatSegment];
}

class MessageSent extends GameplayState {
  final Message message;

  MessageSent(this.message);

  @override
  List<Object?> get props => [message];
}

class PlayerReadyStatusChanged extends GameplayState {
  final Player player;

  PlayerReadyStatusChanged(this.player);

  @override
  List<Object?> get props => [player];
}

class GameStarted extends GameplayState {
  final Game game;

  GameStarted(this.game);

  @override
  List<Object?> get props => [game];
}

class GameRestarted extends GameplayState {
  final Game game;

  GameRestarted(this.game);

  @override
  List<Object?> get props => [game];
}

class PlayerKicked extends GameplayState {
  final Player player;

  PlayerKicked(this.player);

  @override
  List<Object?> get props => [player];
}

class PlayerPromoted extends GameplayState {
  final Player player;

  PlayerPromoted(this.player);

  @override
  List<Object?> get props => [player];
}

class GameplayFailure extends GameplayState {
  final String message;

  GameplayFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// Кубит для работы с игровым процессом
class GameplayCubit extends Cubit<GameplayState> {
  final GameplayService _gameplayService;

  GameplayCubit({required GameplayService gameplayService})
    : _gameplayService = gameplayService,
      super(GameplayInitial());

  // Загрузить текущее состояние игры
  Future<void> loadGameState(int gameId) async {
    emit(GameplayLoading());
    try {
      final gameState = await _gameplayService.getGameState(gameId);
      emit(GameStateLoaded(gameState));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Загрузить сегмент чата
  Future<void> loadChat({
    required int gameId,
    required int chatId,
    int? before,
    int? after,
  }) async {
    emit(GameplayLoading());
    try {
      final chatSegment = await _gameplayService.getChatSegment(
        gameId,
        chatId,
        before: before,
        after: after,
      );
      emit(ChatLoaded(chatSegment));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Отправить сообщение
  Future<void> sendMessage({
    required int gameId,
    required int chatId,
    required String text,
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = await _gameplayService.sendMessage(
        gameId,
        chatId,
        text,
        special: special,
        metadata: metadata,
      );
      emit(MessageSent(message));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Установить статус готовности
  Future<void> setReady(int gameId, bool isReady) async {
    try {
      final player = await _gameplayService.setReady(gameId, isReady);
      emit(PlayerReadyStatusChanged(player));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Начать игру
  Future<void> startGame(int gameId, {bool force = false}) async {
    emit(GameplayLoading());
    try {
      final game = await _gameplayService.startGame(gameId, force: force);
      emit(GameStarted(game));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Выгнать игрока
  Future<void> kickPlayer(int gameId, int playerId) async {
    try {
      final player = await _gameplayService.kickPlayer(gameId, playerId);
      emit(PlayerKicked(player));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Назначить игрока хостом
  Future<void> promotePlayer(int gameId, int playerId) async {
    try {
      final player = await _gameplayService.promotePlayer(gameId, playerId);
      emit(PlayerPromoted(player));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }
}
