import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';
import '/features/games/domain/models/player.dart';
import '/features/chat/domain/models/game_state.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Реальная реализация сервиса игрового процесса
class GameplayServiceImpl extends BaseService implements GameplayService {
  WebSocketChannel? _wsChannel;
  StreamController<Map<String, dynamic>>? _wsController;
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  int? _currentGameId;
  bool _isManualDisconnect = false;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 1000; // 1 second
  StreamSubscription? _wsStreamSubscription;

  GameplayServiceImpl({required super.apiClient});

  @override
  Future<GameState> getGameState(int gameId) async {
    developer.log('[SERVICE:GAMEPLAY] getGameState($gameId) -> GET /game/$gameId/state');
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
    developer.log('[SERVICE:GAMEPLAY] getChatSegment(gameId=$gameId, chatId=$chatId) -> GET /game/$gameId/chat/$chatId');
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
    developer.log('[SERVICE:GAMEPLAY] sendMessage(chatId=$chatId) -> POST /game/$gameId/chat/$chatId/send');
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
    developer.log('[SERVICE:GAMEPLAY] kickPlayer(gameId=$gameId, playerId=$playerId) -> POST /game/$gameId/kick');
    return apiClient.post<Player>(
      '/game/$gameId/kick',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> promotePlayer(int gameId, int playerId) async {
    developer.log('[SERVICE:GAMEPLAY] promotePlayer(gameId=$gameId, playerId=$playerId) -> POST /game/$gameId/promote');
    return apiClient.post<Player>(
      '/game/$gameId/promote',
      data: {'id': playerId},
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Player> setReady(int gameId, bool isReady) async {
    developer.log('[SERVICE:GAMEPLAY] setReady(gameId=$gameId, isReady=$isReady) -> POST /game/$gameId/ready');
    return apiClient.post<Player>(
      '/game/$gameId/ready',
      data: {'ready': isReady},  // Backend expects 'ready' not 'is_ready'
      fromJson: (data) => Player.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> startGame(int gameId, {bool force = false}) async {
    developer.log('[SERVICE:GAMEPLAY] startGame(gameId=$gameId, force=$force) -> POST /game/$gameId/start');
    final queryParams = force ? {'force': 'true'} : <String, String>{};
    return apiClient.post<Game>(
      '/game/$gameId/start',
      queryParameters: queryParams,
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Game> restartGame(int gameId) async {
    developer.log('[SERVICE:GAMEPLAY] restartGame(gameId=$gameId) -> POST /game/$gameId/restart');
    return apiClient.post<Game>(
      '/game/$gameId/restart',
      fromJson: (data) => Game.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Stream<Map<String, dynamic>> connectWebSocket(int gameId) {
    developer.log('[SERVICE:GAMEPLAY] connectWebSocket(gameId=$gameId)');
    disconnectWebSocket();

    _currentGameId = gameId;
    _isManualDisconnect = false;
    _reconnectAttempts = 0;
    _wsController = StreamController<Map<String, dynamic>>.broadcast();

    _connectWebSocketInternal(gameId);

    return _wsController!.stream;
  }

  void _connectWebSocketInternal(int gameId) {
    if (_isManualDisconnect) {
      developer.log('[SERVICE:GAMEPLAY] Skipping connection, manual disconnect requested');
      return;
    }

    final isReconnect = _reconnectAttempts > 0;
    _connectionState = isReconnect ? WebSocketConnectionState.reconnecting : WebSocketConnectionState.connecting;

    // Emit connection state event
    _wsController?.add({
      'type': '_connection_state',
      'payload': {'state': _connectionState.name, 'attempts': _reconnectAttempts},
    });

    developer.log(
      '[SERVICE:GAMEPLAY] ${isReconnect ? "Reconnecting" : "Connecting"} WebSocket (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)'
    );

    final baseUrl = apiClient.baseUrl;
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/game/$gameId/ws'),
      );

      _wsStreamSubscription?.cancel();
      _wsStreamSubscription = _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            
            // Filter out pong - no need to log keep-alive responses
            if (type == 'pong') return;
            
            // Connection successful, reset reconnect attempts
            if (_connectionState != WebSocketConnectionState.connected) {
              _connectionState = WebSocketConnectionState.connected;
              _reconnectAttempts = 0;
              developer.log('[SERVICE:GAMEPLAY] WebSocket connected successfully');
              _wsController?.add({
                'type': '_connection_state',
                'payload': {'state': _connectionState.name, 'attempts': 0},
              });
            }
            
            // Log all other events
            developer.log('[SERVICE:GAMEPLAY] WebSocket event: $type');
            
            _wsController?.add(data);
          } catch (e) {
            developer.log('[SERVICE:GAMEPLAY] WebSocket decode error', error: e);
          }
        },
        onError: (error) {
          developer.log('[SERVICE:GAMEPLAY] WebSocket error', error: error);
          _handleWebSocketDisconnection(gameId);
        },
        onDone: () {
          developer.log('[SERVICE:GAMEPLAY] WebSocket closed');
          _handleWebSocketDisconnection(gameId);
        },
        cancelOnError: false,
      );

      _startPingTimer();
    } catch (e) {
      developer.log('[SERVICE:GAMEPLAY] WebSocket connect error', error: e);
      _handleWebSocketDisconnection(gameId);
    }
  }

  void _handleWebSocketDisconnection(int gameId) {
    if (_isManualDisconnect) {
      developer.log('[SERVICE:GAMEPLAY] Manual disconnect, not reconnecting');
      _connectionState = WebSocketConnectionState.disconnected;
      _wsController?.add({
        'type': '_connection_state',
        'payload': {'state': _connectionState.name, 'attempts': _reconnectAttempts},
      });
      _wsController?.close();
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      developer.log('[SERVICE:GAMEPLAY] Max reconnect attempts reached, giving up');
      _connectionState = WebSocketConnectionState.disconnected;
      _wsController?.add({
        'type': '_connection_state',
        'payload': {'state': _connectionState.name, 'attempts': _reconnectAttempts},
      });
      _wsController?.addError('Failed to reconnect after $_maxReconnectAttempts attempts');
      _wsController?.close();
      return;
    }

    // Calculate exponential backoff delay
    final delay = _baseReconnectDelay * (1 << _reconnectAttempts); // 2^attempts
    final cappedDelay = delay > 30000 ? 30000 : delay; // Max 30 seconds

    developer.log('[SERVICE:GAMEPLAY] Scheduling reconnect in ${cappedDelay}ms');
    _reconnectAttempts++;
    _connectionState = WebSocketConnectionState.reconnecting;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: cappedDelay), () {
      _connectWebSocketInternal(gameId);
    });
  }

  Timer? _pingTimer;

  void _startPingTimer() {
    _pingTimer?.cancel();
    // Ping every 20 seconds to keep connection alive
    // Backend times out after 5s waiting for messages, so this ensures we send something regularly
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_wsChannel != null && _connectionState == WebSocketConnectionState.connected) {
        try {
          _wsChannel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          developer.log('[SERVICE:GAMEPLAY] Ping failed', error: e);
          timer.cancel();
          if (_currentGameId != null) {
            _handleWebSocketDisconnection(_currentGameId!);
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void disconnectWebSocket() {
    if (_wsChannel != null || _pingTimer != null) {
      developer.log('[SERVICE:GAMEPLAY] disconnectWebSocket()');
    }
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _wsStreamSubscription?.cancel();
    _wsStreamSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsController?.close();
    _wsController = null;
    _connectionState = WebSocketConnectionState.disconnected;
    _reconnectAttempts = 0;
    _currentGameId = null;
  }
}
