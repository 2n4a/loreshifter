enum MessageKind {
  player,
  system,
  characterCreation,
  generalInfo,
  publicInfo,
  privateInfo,
}

class Sender {
  final int? id;
  final String name;
  final String type; // 'user', 'system', 'assistant'

  Sender({this.id, required this.name, required this.type});
}

class Message {
  final int id;
  final int chatId;
  final int? senderId;
  final MessageKind kind;
  final String text;
  final String? special;
  final DateTime sentAt;
  final Map<String, dynamic>? metadata;
  late final Sender sender;

  Message({
    required this.id,
    required this.chatId,
    this.senderId,
    required this.kind,
    required this.text,
    this.special,
    required this.sentAt,
    this.metadata,
  }) {
    var senderName = metadata?['senderName'] as String?;
    if (senderName == 'Пользователь') {
      senderName = null;
    }
    senderName ??= _getDefaultSenderName(kind);

    final senderType = _getSenderType(kind);
    sender = Sender(id: senderId, name: senderName, type: senderType);
  }

  static String _getDefaultSenderName(MessageKind kind) {
    switch (kind) {
      case MessageKind.player:
        return 'Игрок';
      case MessageKind.system:
        return 'Система';
      case MessageKind.characterCreation:
        return 'Мастер персонажа';
      case MessageKind.generalInfo:
      case MessageKind.publicInfo:
      case MessageKind.privateInfo:
        return 'Мастер';
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final chatId = json['chatId'] ?? json['chat_id'];
    final senderId = json['senderId'] ?? json['sender_id'];
    final sentAt = json['sentAt'] ?? json['sent_at'];
    return Message(
      id: json['id'] as int,
      chatId: chatId as int,
      senderId: senderId as int?,
      kind: _parseMessageKind(json['kind'] as String),
      text: json['text'] as String,
      special: json['special'] as String?,
      sentAt: DateTime.parse(sentAt as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static String _getSenderType(MessageKind kind) {
    switch (kind) {
      case MessageKind.player:
        return 'user';
      case MessageKind.system:
        return 'system';
      case MessageKind.characterCreation:
      case MessageKind.generalInfo:
      case MessageKind.publicInfo:
      case MessageKind.privateInfo:
        return 'assistant';
    }
  }

  static MessageKind _parseMessageKind(String kind) {
    switch (kind) {
      case 'player':
        return MessageKind.player;
      case 'system':
        return MessageKind.system;
      case 'characterCreation':
      case 'character_creation':
        return MessageKind.characterCreation;
      case 'generalInfo':
      case 'general_info':
        return MessageKind.generalInfo;
      case 'publicInfo':
      case 'public_info':
        return MessageKind.publicInfo;
      case 'privateInfo':
      case 'private_info':
        return MessageKind.privateInfo;
      default:
        return MessageKind.system;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      if (senderId != null) 'senderId': senderId,
      'kind': kind.toString().split('.').last,
      'text': text,
      if (special != null) 'special': special,
      'sentAt': sentAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class MessageOut {
  final String text;
  final String? special;
  final Map<String, dynamic>? metadata;

  MessageOut({required this.text, this.special, this.metadata});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (special != null) 'special': special,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
