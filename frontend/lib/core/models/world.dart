import '/core/models/user.dart';

// Определяем enum для типов миров
enum WorldType {
  fantasy, // Фэнтези
  scifi, // Научная фантастика
  historical, // Исторический
  horror, // Хоррор
  other, // Другой
}

class World {
  final int id;
  final String name;
  final bool public;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final User owner;
  final String? description;
  final dynamic data;
  final WorldType type; // Новое поле для типа мира
  final int rating; // Поле для рейтинга

  World({
    required this.id,
    required this.name,
    required this.public,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.owner,
    this.description,
    this.data,
    this.type = WorldType.fantasy, // По умолчанию тип фэнтези
    this.rating = 0, // По умолчанию рейтинг 0
  });

  factory World.fromJson(Map<String, dynamic> json) {
    // Преобразование строки в WorldType
    WorldType getWorldTypeFromString(String? typeStr) {
      if (typeStr == null) return WorldType.fantasy;

      switch (typeStr.toLowerCase()) {
        case 'fantasy':
          return WorldType.fantasy;
        case 'scifi':
          return WorldType.scifi;
        case 'historical':
          return WorldType.historical;
        case 'horror':
          return WorldType.horror;
        default:
          return WorldType.other;
      }
    }

    return World(
      id: json['id'] as int,
      name: json['name'] as String,
      public: json['public'] as bool,
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt']),
      owner: User.fromJson(json['owner']),
      description: json['description'] as String?,
      data: json['data'],
      // Добавляем чтение типа из JSON
      type: getWorldTypeFromString(json['type'] as String?),
      // Добавляем чтение рейтинга из JSON
      rating: (json['rating'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // Преобразование WorldType в строку
    String worldTypeToString(WorldType type) {
      switch (type) {
        case WorldType.fantasy:
          return 'fantasy';
        case WorldType.scifi:
          return 'scifi';
        case WorldType.historical:
          return 'historical';
        case WorldType.horror:
          return 'horror';
        case WorldType.other:
          return 'other';
      }
    }

    return {
      'id': id,
      'name': name,
      'public': public,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'owner': owner.toJson(),
      if (description != null) 'description': description,
      if (data != null) 'data': data,
      'type': worldTypeToString(type), // Добавляем запись типа в JSON
      'rating': rating, // Добавляем запись рейтинга в JSON
    };
  }
}
