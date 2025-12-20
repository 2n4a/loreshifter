import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/chat/domain/models/game_state.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса игрового процесса
class GameplayServiceImpl extends BaseService implements GameplayService {
  WebSocketChannel? _wsChannel;
  StreamController<Map<String, dynamic>>? _wsController;

  GameplayServiceImpl({required super.apiClient});

  @override
  Future<GameState> getGameState(int gameId) async {
    developer.log('GameplayService: Запрос состояния игры $gameId');
    return apiClient.get<GameState>(
      '/game/$gameId/state',
      fromJson: (data) => GameState.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<ChatSegment> getChatSegment(
    int gameId,
    int chatId, {
    int? before,
    int? after,
    int limit = 50,
  }) async {
    developer.log('GameplayService: Запрос сегмента чата $chatId в игре $gameId');
    final queryParams = <String, dynamic>{
      'limit': limit.toString(),
    };
    if (before != null) queryParams['before'] = before.toString();
    if (after != null) queryParams['after'] = after.toString();

    return apiClient.get<ChatSegment>(
      '/game/$gameId/chat/$chatId',
      queryParameters: queryParams,
      fromJson: (data) => ChatSegment.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Message> sendMessage(
    int gameId,
    int chatId,
    String text, {
    String? special,
    Map<String, dynamic>? metadata,
  }) async {
    developer.log('GameplayService: Отправка сообщения в чат $chatId игры $gameId');
    final body = <String, dynamic>{
      'text': text,
    };
    if (special != null) body['special'] = special;
    if (metadata != null) body['metadata'] = metadata;

    return apiClient.post<Message>(
      '/game/$gameId/chat/$chatId/send',
      data: body,
      fromJson: (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> kickPlayer(int gameId, int playerId) async {
    developer.log('GameplayService: Исключение игрока $playerId из игры $gameId');
    return apiClient.post<Player>(
      '/game/$gameId/kick',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> promotePlayer(int gameId, int playerId) async {
    developer.log('GameplayService: Назначение игрока $playerId хостом игры $gameId');
    return apiClient.post<Player>(
      '/game/$gameId/promote',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> setReady(int gameId, bool isReady) async {
    developer.log('GameplayService: Установка статуса готовности в игре $gameId: $isReady');
    return apiClient.post<Player>(
      '/game/$gameId/ready',
      data: {'is_ready': isReady},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> startGame(int gameId, {bool force = false}) async {
    developer.log('GameplayService: Запуск игры $gameId (force: $force)');
    final queryParams = force ? {'force': 'true'} : <String, String>{};
    return apiClient.post<Game>(
      '/game/$gameId/start',
      queryParameters: queryParams,
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Stream<Map<String, dynamic>> connectWebSocket(int gameId) {
    developer.log('GameplayService: Подключение к WebSocket игры $gameId');
    disconnectWebSocket();

    _wsController = StreamController<Map<String, dynamic>>.broadcast();

    // Convert HTTP(S) URL to WS(S) URL
    final baseUrl = apiClient.baseUrl;
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/game/$gameId/ws'),
      );

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            developer.log('GameplayService: Получено WebSocket сообщение: ${data['type']}');
            _wsController?.add(data);
          } catch (e) {
            developer.log('GameplayService: Ошибка декодирования WebSocket сообщения: $e');
          }
        },
        onError: (error) {
          developer.log('GameplayService: Ошибка WebSocket: $error');
          _wsController?.addError(error);
        },
        onDone: () {
          developer.log('GameplayService: WebSocket соединение закрыто');
          _wsController?.close();
        },
      );
    } catch (e) {
      developer.log('GameplayService: Ошибка подключения к WebSocket: $e');
      _wsController?.addError(e);
    }

    return _wsController!.stream;
  }

  @override
  void disconnectWebSocket() {
    developer.log('GameplayService: Отключение от WebSocket');
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsController?.close();
    _wsController = null;
  }
}
