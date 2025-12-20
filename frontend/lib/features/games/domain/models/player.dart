import '/features/auth/domain/models/user.dart';

class Player {
  final User user;
  final bool isReady;
  final bool isHost;
  final bool isSpectator;

  Player({
    required this.user,
    required this.isReady,
    required this.isHost,
    required this.isSpectator,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      user: User.fromJson(json['user']),
      isReady: json['is_ready'] as bool,
      isHost: json['is_host'] as bool,
      isSpectator: json['is_spectator'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'is_ready': isReady,
      'is_host': isHost,
      'is_spectator': isSpectator,
    };
  }
}

