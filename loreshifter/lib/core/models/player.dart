import 'package:loreshifter/core/models/user.dart';

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
      isReady: json['isReady'] as bool,
      isHost: json['isHost'] as bool,
      isSpectator: json['isSpectator'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'isReady': isReady,
      'isHost': isHost,
      'isSpectator': isSpectator,
    };
  }
}
