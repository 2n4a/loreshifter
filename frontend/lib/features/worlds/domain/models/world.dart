import '/features/auth/domain/models/user.dart';

class World {
  final int id;
  final String name;
  final bool public;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final User owner;
  final String? description;
  final dynamic data;
  final bool deleted;

  World({
    required this.id,
    required this.name,
    required this.public,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.owner,
    this.description,
    this.data,
    this.deleted = false,
  });

  factory World.fromJson(Map<String, dynamic> json) {
    return World(
      id: json['id'] as int,
      name: json['name'] as String,
      public: json['public'] as bool,
      createdAt: DateTime.parse(json['created_at']),
      lastUpdatedAt: DateTime.parse(json['last_updated_at']),
      owner: User.fromJson(json['owner']),
      description: json['description'] as String?,
      data: json['data'],
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'public': public,
      'created_at': createdAt.toIso8601String(),
      'last_updated_at': lastUpdatedAt.toIso8601String(),
      'owner': owner.toJson(),
      if (description != null) 'description': description,
      if (data != null) 'data': data,
      'deleted': deleted,
    };
  }
}

