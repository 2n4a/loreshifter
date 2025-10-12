import '/features/chat/domain/models/message.dart';

enum ChatInterfaceType { readonly, foreign, full, timed, foreignTimed }

class ChatInterface {
  final ChatInterfaceType type;
  final DateTime? deadline;

  ChatInterface({required this.type, this.deadline});

  factory ChatInterface.fromJson(Map<String, dynamic> json) {
    return ChatInterface(
      type: _parseChatInterfaceType(json['type'] as String),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    );
  }

  static ChatInterfaceType _parseChatInterfaceType(String type) {
    switch (type) {
      case 'readonly':
        return ChatInterfaceType.readonly;
      case 'foreign':
        return ChatInterfaceType.foreign;
      case 'full':
        return ChatInterfaceType.full;
      case 'timed':
        return ChatInterfaceType.timed;
      case 'foreignTimed':
        return ChatInterfaceType.foreignTimed;
      default:
        return ChatInterfaceType.readonly;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
    };
  }
}

class ChatSegment {
  final int chatId;
  final int? chatOwner;
  final List<Message> messages;
  final int? previousId;
  final int? nextId;
  final List<String> suggestions;
  final ChatInterface interface;

  ChatSegment({
    required this.chatId,
    this.chatOwner,
    required this.messages,
    this.previousId,
    this.nextId,
    required this.suggestions,
    required this.interface,
  });

  factory ChatSegment.fromJson(Map<String, dynamic> json) {
    return ChatSegment(
      chatId: json['chatId'] as int,
      chatOwner: json['chatOwner'] as int?,
      messages: (json['messages'] as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      previousId: json['previousId'] as int?,
      nextId: json['nextId'] as int?,
      suggestions: (json['suggestions'] as List).map((e) => e as String).toList(),
      interface: ChatInterface.fromJson(json['interface']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      if (chatOwner != null) 'chatOwner': chatOwner,
      'messages': messages.map((e) => e.toJson()).toList(),
      'previousId': previousId,
      'nextId': nextId,
      'suggestions': suggestions,
      'interface': interface.toJson(),
    };
  }
}

