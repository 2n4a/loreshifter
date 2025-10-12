import '/features/auth/domain/models/user.dart';

enum WorldType { fantasy, scifi, historical, horror, other }

class World {
  final int id;
  final String name;
  final bool public;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final User owner;
  final String? description;
  final dynamic data;
  final WorldType type;
  final int rating;

  World({
    required this.id,
    required this.name,
    required this.public,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.owner,
    this.description,
    this.data,
    this.type = WorldType.fantasy,
    this.rating = 0,
  });

  factory World.fromJson(Map<String, dynamic> json) {
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
      type: getWorldTypeFromString(json['type'] as String?),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
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
      'type': worldTypeToString(type),
      'rating': rating,
    };
  }
}

