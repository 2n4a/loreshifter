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
    final isReady = (json['isReady'] ?? json['is_ready']) ?? false;
    final isHost = (json['isHost'] ?? json['is_host']) ?? false;
    final isSpectator = (json['isSpectator'] ?? json['is_spectator']) ?? false;
    return Player(
      user: User.fromJson(json['user']),
      isReady: isReady as bool,
      isHost: isHost as bool,
      isSpectator: isSpectator as bool,
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
