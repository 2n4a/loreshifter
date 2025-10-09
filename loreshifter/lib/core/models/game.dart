import 'package:loreshifter/core/models/player.dart';
import 'package:loreshifter/core/models/world.dart';

enum GameStatus { waiting, playing, finished, archived }

class Game {
  final int id;
  final String code;
  final bool public;
  final String name;
  final World world;
  final int hostId;
  final List<Player> players;
  final DateTime createdAt;
  final int maxPlayers;
  final GameStatus status;

  Game({
    required this.id,
    required this.code,
    required this.public,
    required this.name,
    required this.world,
    required this.hostId,
    required this.players,
    required this.createdAt,
    required this.maxPlayers,
    required this.status,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as int,
      code: json['code'] as String,
      public: json['public'] as bool,
      name: json['name'] as String,
      world: World.fromJson(json['world']),
      hostId: json['hostId'] as int,
      players: (json['players'] as List)
          .map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      maxPlayers: json['maxPlayers'] as int,
      status: _parseGameStatus(json['status'] as String),
    );
  }

  static GameStatus _parseGameStatus(String status) {
    switch (status) {
      case 'waiting':
        return GameStatus.waiting;
      case 'playing':
        return GameStatus.playing;
      case 'finished':
        return GameStatus.finished;
      case 'archived':
        return GameStatus.archived;
      default:
        return GameStatus.waiting;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'public': public,
      'name': name,
      'world': world.toJson(),
      'hostId': hostId,
      'players': players.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'maxPlayers': maxPlayers,
      'status': status.toString().split('.').last,
    };
  }
}
