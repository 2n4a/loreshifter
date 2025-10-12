import 'package:flutter/material.dart';
import '/core/models/game.dart';

/// Возвращает локализованный текст статуса игры.
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

/// Возвращает цвет статуса игры.
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

/// Парсит строковый статус в enum GameStatus.
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
