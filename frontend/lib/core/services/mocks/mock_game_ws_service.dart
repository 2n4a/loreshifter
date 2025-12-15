import 'dart:async';
import 'dart:convert';
import '/core/services/interfaces/game_ws_service_interface.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/message.dart';
import 'dart:developer' as developer;

/// Моковая реализация WebSocket сервиса для игры (на стабах)
class MockGameWsService implements GameWsService {
  final _messageController = StreamController<WsMessage>.broadcast();
  int? _currentGameId;
  Timer? _simulationTimer;
  bool _connected = false;

  MockGameWsService();

  @override
  bool get isConnected => _connected;

  @override
  Stream<WsMessage> get messages => _messageController.stream;

  @override
  Future<void> connect(int gameId) async {
    if (_connected && _currentGameId == gameId) {
      developer.log('MockGameWsService: Уже подключен к игре $gameId');
      return;
    }

    _currentGameId = gameId;
    _connected = true;
    developer.log('MockGameWsService: Подключение к игре $gameId (стаб)');

    // Симулируем начальное состояние игры
    await Future.delayed(const Duration(milliseconds: 100));
    _sendStateMessage();

    // Симулируем периодические сообщения
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _simulateRandomMessage();
    });

    developer.log('MockGameWsService: Успешно подключен к игре $gameId (стаб)');
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) {
      return;
    }

    developer.log('MockGameWsService: Отключение от игры $_currentGameId');
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _connected = false;
    _currentGameId = null;
  }

  @override
  Future<void> send(WsMessage message) async {
    if (!_connected) {
      throw Exception('WebSocket не подключен');
    }

    developer.log('MockGameWsService: Отправлено сообщение: ${message.type} (стаб)');

    // Симулируем ответ на ping
    if (message.type == WsMessageType.ping) {
      await Future.delayed(const Duration(milliseconds: 100));
      final pongMessage = WsMessage(
        type: WsMessageType.pong,
        id: message.id,
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
      _messageController.add(pongMessage);
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

  /// Отправляет начальное состояние игры
  void _sendStateMessage() {
    final stateMessage = WsMessage(
      type: WsMessageType.state,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: {
        'status': 'waiting',
        'gameChat': {'chatId': 1, 'title': 'Основной чат'},
        'playerChats': [],
        'adviceChats': [],
      },
    );
    _messageController.add(stateMessage);
  }

  /// Симулирует случайное сообщение
  void _simulateRandomMessage() {
    if (!_connected) return;

    final random = DateTime.now().millisecond % 3;
    switch (random) {
      case 0:
        // Симулируем новое сообщение в чате
        final message = WsMessage(
          type: WsMessageType.message,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          data: {
            'id': DateTime.now().millisecondsSinceEpoch,
            'chatId': 1,
            'senderId': 2,
            'kind': 'system',
            'text': 'Системное сообщение (стаб)',
            'sentAt': DateTime.now().toIso8601String(),
          },
        );
        _messageController.add(message);
        break;
      case 1:
        // Симулируем обновление состояния
        final stateMessage = WsMessage(
          type: WsMessageType.state,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          data: {
            'status': 'waiting',
            'players': [
              {'id': 1, 'isReady': true},
              {'id': 2, 'isReady': false},
            ],
          },
        );
        _messageController.add(stateMessage);
        break;
      case 2:
        // Симулируем обновление чата
        final chatMessage = WsMessage(
          type: WsMessageType.chat,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          data: {
            'chatId': 1,
            'suggestions': ['Привет!', 'Готов играть!', 'Начнем?'],
          },
        );
        _messageController.add(chatMessage);
        break;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    _messageController.close();
  }
}

