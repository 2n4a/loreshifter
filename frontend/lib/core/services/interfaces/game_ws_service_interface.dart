import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';
import '/features/chat/domain/models/message.dart';

/// Типы сообщений WebSocket
enum WsMessageType {
  ping,
  pong,
  state,
  chat,
  message,
  kicked,
  error,
}

/// Базовое сообщение WebSocket
class WsMessage {
  final WsMessageType type;
  final String id;
  final dynamic data;

  WsMessage({
    required this.type,
    required this.id,
    required this.data,
  });

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: _parseMessageType(json['type'] as String),
      id: json['id'] as String,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'id': id,
      'data': data,
    };
  }

  static WsMessageType _parseMessageType(String type) {
    switch (type) {
      case 'ping':
        return WsMessageType.ping;
      case 'pong':
        return WsMessageType.pong;
      case 'state':
        return WsMessageType.state;
      case 'chat':
        return WsMessageType.chat;
      case 'message':
        return WsMessageType.message;
      case 'kicked':
        return WsMessageType.kicked;
      case 'error':
        return WsMessageType.error;
      default:
        return WsMessageType.error;
    }
  }
}

/// Интерфейс для WebSocket сервиса игры
abstract class GameWsService {
  /// Подключиться к игре
  Future<void> connect(int gameId);

  /// Отключиться от игры
  Future<void> disconnect();

  /// Отправить сообщение
  Future<void> send(WsMessage message);

  /// Поток сообщений
  Stream<WsMessage> get messages;

  /// Проверка подключения
  bool get isConnected;

  /// Отправить ping
  Future<void> sendPing();
}

