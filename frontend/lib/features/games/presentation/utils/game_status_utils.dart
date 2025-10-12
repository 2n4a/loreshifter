import 'package:flutter/material.dart';
import '/features/games/domain/models/game.dart';

String gameStatusLabel(GameStatus status, {bool uppercase = false}) {
  String text;
  switch (status) {
    case GameStatus.waiting:
      text = 'Ожидание';
      break;
    case GameStatus.playing:
      text = 'В процессе';
      break;
    case GameStatus.finished:
      text = 'Завершена';
      break;
    case GameStatus.archived:
      text = 'В архиве';
      break;
  }
  return uppercase ? text.toUpperCase() : text;
}

Color gameStatusColor(GameStatus status) {
  switch (status) {
    case GameStatus.waiting:
      return Colors.blue;
    case GameStatus.playing:
      return Colors.green;
    case GameStatus.finished:
      return Colors.orange;
    case GameStatus.archived:
      return Colors.grey;
  }
}

GameStatus? tryParseGameStatus(String? status) {
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
      return null;
  }
}

