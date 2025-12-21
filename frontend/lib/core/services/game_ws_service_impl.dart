import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '/core/services/interfaces/game_ws_service_interface.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/message.dart';
import 'dart:developer' as developer;

/// Реальная реализация WebSocket сервиса для игры
class GameWsServiceImpl implements GameWsService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<WsMessage>.broadcast();
  final String baseUrl;
  int? _currentGameId;
  Timer? _pingTimer;

  GameWsServiceImpl({required this.baseUrl});

  @override
  bool get isConnected => _channel != null;

  @override
  Stream<WsMessage> get messages => _messageController.stream;

  @override
  Future<void> connect(int gameId) async {
    if (_channel != null && _currentGameId == gameId) {
      developer.log('GameWsService: Уже подключен к игре $gameId');
      return;
    }

    // Отключаемся от предыдущего соединения, если есть
    if (_channel != null) {
      await disconnect();
    }

    _currentGameId = gameId;
    developer.log('GameWsService: Подключение к игре $gameId');

    try {
      // Преобразуем HTTP URL в WebSocket URL
      final wsUrl = _convertToWsUrl(baseUrl, '/game/$gameId/ws');
      developer.log('GameWsService: WebSocket URL: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Слушаем сообщения
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final message = WsMessage.fromJson(json);
            developer.log('GameWsService: Получено сообщение: ${message.type}');
            _messageController.add(message);
          } catch (e) {
            developer.log('GameWsService: Ошибка парсинга сообщения', error: e);
          }
        },
        onError: (error) {
          developer.log('GameWsService: Ошибка WebSocket', error: error);
          _messageController.addError(error);
        },
        onDone: () {
          developer.log('GameWsService: WebSocket соединение закрыто');
          _channel = null;
          _currentGameId = null;
          _pingTimer?.cancel();
          _pingTimer = null;
        },
      );

      // Запускаем ping каждые 30 секунд
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        sendPing();
      });

      developer.log('GameWsService: Успешно подключен к игре $gameId');
    } catch (e) {
      developer.log('GameWsService: Ошибка подключения', error: e);
      _channel = null;
      _currentGameId = null;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_channel == null) {
      return;
    }

    developer.log('GameWsService: Отключение от игры $_currentGameId');
    _pingTimer?.cancel();
    _pingTimer = null;

    await _channel!.sink.close();
    _channel = null;
    _currentGameId = null;
  }

  @override
  Future<void> send(WsMessage message) async {
    if (_channel == null) {
      throw Exception('WebSocket не подключен');
    }

    try {
      final json = jsonEncode(message.toJson());
      _channel!.sink.add(json);
      developer.log('GameWsService: Отправлено сообщение: ${message.type}');
    } catch (e) {
      developer.log('GameWsService: Ошибка отправки сообщения', error: e);
      rethrow;
    }
  }

  @override
  Future<void> sendPing() async {
    final pingId = DateTime.now().millisecondsSinceEpoch.toString();
    final pingMessage = WsMessage(
      type: WsMessageType.ping,
      id: pingId,
      data: {'timestamp': DateTime.now().toIso8601String()},
    );
    await send(pingMessage);
  }

  /// Преобразует HTTP URL в WebSocket URL
  String _convertToWsUrl(String httpUrl, String path) {
    final uri = Uri.parse(httpUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    final port = uri.port;
    final basePath = uri.path.isEmpty || uri.path == '/'
        ? ''
        : (uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path);
    final wsPath = path.startsWith('/') ? path : '/$path';
    final fullPath = '$basePath$wsPath';

    if (port != 80 && port != 443) {
      return '$scheme://$host:$port$fullPath';
    }
    return '$scheme://$host$fullPath';
  }

  Future<void> dispose() async {
    await disconnect();
    _messageController.close();
  }
}
