import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loreshifter/core/models/chat.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/message.dart';
import 'package:loreshifter/core/models/player.dart';
import 'package:loreshifter/core/services/gameplay_service.dart';

// События для работы с игровым процессом
abstract class GameplayEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGameStateRequested extends GameplayEvent {}

class LoadChatRequested extends GameplayEvent {
  final int chatId;
  final int? before;
  final int? after;

  LoadChatRequested({required this.chatId, this.before, this.after});

  @override
  List<Object?> get props => [chatId, before, after];
}

class SendMessageRequested extends GameplayEvent {
  final int chatId;
  final String text;
  final String? special;
  final Map<String, dynamic>? metadata;

  SendMessageRequested({
    required this.chatId,
    required this.text,
    this.special,
    this.metadata,
  });

  @override
  List<Object?> get props => [chatId, text, special, metadata];
}

class SetReadyStatusRequested extends GameplayEvent {
  final bool isReady;

  SetReadyStatusRequested(this.isReady);

  @override
  List<Object?> get props => [isReady];
}

class StartGameRequested extends GameplayEvent {
  final bool force;

  StartGameRequested({this.force = false});

  @override
  List<Object?> get props => [force];
}

class RestartGameRequested extends GameplayEvent {}

// Состояния для работы с игровым процессом
abstract class GameplayState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameplayInitial extends GameplayState {}

class GameplayLoading extends GameplayState {}

class GameStateLoaded extends GameplayState {
  final dynamic gameState;

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
  Future<void> loadGameState() async {
    emit(GameplayLoading());
    try {
      final gameState = await _gameplayService.getGameState();
      emit(GameStateLoaded(gameState));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Загрузить сегмент чата
  Future<void> loadChat({required int chatId, int? before, int? after}) async {
    emit(GameplayLoading());
    try {
      final chatSegment = await _gameplayService.getChatSegment(
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
    required int chatId,
    required String text,
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = await _gameplayService.sendMessage(
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
  Future<void> setReady(bool isReady) async {
    try {
      final player = await _gameplayService.setReady(isReady);
      emit(PlayerReadyStatusChanged(player));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Начать игру
  Future<void> startGame({bool force = false}) async {
    emit(GameplayLoading());
    try {
      final game = await _gameplayService.startGame(force: force);
      emit(GameStarted(game));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }

  // Перезапустить игру
  Future<void> restartGame() async {
    emit(GameplayLoading());
    try {
      final game = await _gameplayService.restartGame();
      emit(GameRestarted(game));
    } catch (e) {
      emit(GameplayFailure(e.toString()));
    }
  }
}
