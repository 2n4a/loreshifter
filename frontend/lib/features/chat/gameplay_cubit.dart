import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/chat/domain/models/game_state.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';
import 'dart:developer' as developer;

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

class WebSocketEvent extends GameplayState {
  final String type;
  final Map<String, dynamic> payload;

  WebSocketEvent({required this.type, required this.payload});

  @override
  List<Object?> get props => [type, payload];
}

// Кубит для работы с игровым процессом
class GameplayCubit extends Cubit<GameplayState> {
  final GameplayService _gameplayService;

  GameplayCubit({required GameplayService gameplayService})
    : _gameplayService = gameplayService,
      super(GameplayInitial());

  // Загрузить текущее состояние игры
  Future<void> loadGameState(int gameId) async {
    developer.log('[CUBIT:GAMEPLAY] loadGameState($gameId) started');
    emit(GameplayLoading());
    try {
      final gameState = await _gameplayService.getGameState(gameId);
      developer.log('[CUBIT:GAMEPLAY] loadGameState() -> GameStateLoaded');
      emit(GameStateLoaded(gameState));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] loadGameState() -> Error', error: e);
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
    developer.log('[CUBIT:GAMEPLAY] loadChat(gameId=$gameId, chatId=$chatId) started');
    emit(GameplayLoading());
    try {
      final chatSegment = await _gameplayService.getChatSegment(
        gameId,
        chatId,
        before: before,
        after: after,
      );
      developer.log('[CUBIT:GAMEPLAY] loadChat() -> ChatLoaded(messageCount=${chatSegment.messages.length})');
      emit(ChatLoaded(chatSegment));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] loadChat() -> Error', error: e);
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
    developer.log('[CUBIT:GAMEPLAY] sendMessage(chatId=$chatId, text="${text.substring(0, text.length > 20 ? 20 : text.length)}...") started');
    try {
      final message = await _gameplayService.sendMessage(
        gameId,
        chatId,
        text,
        special: special,
        metadata: metadata,
      );
      developer.log('[CUBIT:GAMEPLAY] sendMessage() -> MessageSent(id=${message.id})');
      emit(MessageSent(message));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] sendMessage() -> Error', error: e);
      emit(GameplayFailure(e.toString()));
    }
  }

  // Установить статус готовности
  Future<void> setReady(int gameId, bool isReady) async {
    developer.log('[CUBIT:GAMEPLAY] setReady(gameId=$gameId, isReady=$isReady) started');
    try {
      final player = await _gameplayService.setReady(gameId, isReady);
      developer.log('[CUBIT:GAMEPLAY] setReady() -> PlayerReadyStatusChanged(playerId=${player.user.id})');
      emit(PlayerReadyStatusChanged(player));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] setReady() -> Error', error: e);
      emit(GameplayFailure(e.toString()));
    }
  }

  // Начать игру
  Future<void> startGame(int gameId, {bool force = false}) async {
    developer.log('[CUBIT:GAMEPLAY] startGame(gameId=$gameId, force=$force) started');
    emit(GameplayLoading());
    try {
      final game = await _gameplayService.startGame(gameId, force: force);
      developer.log('[CUBIT:GAMEPLAY] startGame() -> GameStarted(id=${game.id})');
      emit(GameStarted(game));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] startGame() -> Error', error: e);
      emit(GameplayFailure(e.toString()));
    }
  }

  // Выгнать игрока
  Future<void> kickPlayer(int gameId, int playerId) async {
    developer.log('[CUBIT:GAMEPLAY] kickPlayer(gameId=$gameId, playerId=$playerId) started');
    try {
      final player = await _gameplayService.kickPlayer(gameId, playerId);
      developer.log('[CUBIT:GAMEPLAY] kickPlayer() -> PlayerKicked(playerId=${player.user.id})');
      emit(PlayerKicked(player));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] kickPlayer() -> Error', error: e);
      emit(GameplayFailure(e.toString()));
    }
  }

  // Назначить игрока хостом
  Future<void> promotePlayer(int gameId, int playerId) async {
    developer.log('[CUBIT:GAMEPLAY] promotePlayer(gameId=$gameId, playerId=$playerId) started');
    try {
      final player = await _gameplayService.promotePlayer(gameId, playerId);
      developer.log('[CUBIT:GAMEPLAY] promotePlayer() -> PlayerPromoted(playerId=${player.user.id})');
      emit(PlayerPromoted(player));
    } catch (e) {
      developer.log('[CUBIT:GAMEPLAY] promotePlayer() -> Error', error: e);
      emit(GameplayFailure(e.toString()));
    }
  }

  // Подключиться к WebSocket и получать события
  Stream<Map<String, dynamic>> connectWebSocket(int gameId) {
    developer.log('[CUBIT:GAMEPLAY] connectWebSocket(gameId=$gameId)');
    return _gameplayService.connectWebSocket(gameId);
  }

  // Отключиться от WebSocket
  void disconnectWebSocket() {
    developer.log('[CUBIT:GAMEPLAY] disconnectWebSocket()');
    _gameplayService.disconnectWebSocket();
  }
}
