import '/features/chat/domain/models/chat.dart';
import '/features/games/domain/models/game.dart';

/// Represents the complete state of a game session
class GameState {
  final Game game;
  final GameStatus status;
  final ChatSegment? characterCreationChat;
  final ChatSegment? gameChat;
  final List<ChatSegment> playerChats;
  final List<ChatSegment> adviceChats;

  GameState({
    required this.game,
    required this.status,
    this.characterCreationChat,
    this.gameChat,
    this.playerChats = const [],
    this.adviceChats = const [],
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      game: Game.fromJson(json['game']),
      status: _parseGameStatus(json['status'] as String),
      characterCreationChat: json['character_creation_chat'] != null
          ? ChatSegment.fromJson(json['character_creation_chat'])
          : null,
      gameChat: json['game_chat'] != null
          ? ChatSegment.fromJson(json['game_chat'])
          : null,
      playerChats: json['player_chats'] != null
          ? (json['player_chats'] as List)
              .map((e) => ChatSegment.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      adviceChats: json['advice_chats'] != null
          ? (json['advice_chats'] as List)
              .map((e) => ChatSegment.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
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
      'game': game.toJson(),
      'status': status.toString().split('.').last,
      'character_creation_chat': characterCreationChat?.toJson(),
      'game_chat': gameChat?.toJson(),
      'player_chats': playerChats.map((e) => e.toJson()).toList(),
      'advice_chats': adviceChats.map((e) => e.toJson()).toList(),
    };
  }
}
