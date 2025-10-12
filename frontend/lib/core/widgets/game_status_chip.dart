import 'package:flutter/material.dart';
import '/core/models/game.dart';
import '/core/utils/game_status_utils.dart';

class GameStatusChip extends StatelessWidget {
  final GameStatus status;
  final bool uppercase;

  const GameStatusChip({
    super.key,
    required this.status,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = gameStatusColor(status);
    final label = gameStatusLabel(status, uppercase: uppercase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
