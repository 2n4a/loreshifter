import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/games/domain/models/game.dart';
import '/features/games/games_cubit.dart';
import '/features/games/presentation/widgets/game_status_chip.dart';

class WorldHistoryScreen extends StatefulWidget {
  final int worldId;

  const WorldHistoryScreen({super.key, required this.worldId});

  @override
  State<WorldHistoryScreen> createState() => _WorldHistoryScreenState();
}

class _WorldHistoryScreenState extends State<WorldHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GamesCubit>().loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История мира')),
      body: BlocBuilder<GamesCubit, GamesState>(
        builder: (context, state) {
          if (state is GamesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GamesLoaded) {
            final games =
                state.games.where((g) => g.world.id == widget.worldId).toList();
            if (games.isEmpty) {
              return const Center(child: Text('История пуста'));
            }
            return ListView.separated(
              itemCount: games.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _GameTile(game: games[index]),
            );
          }
          if (state is GamesFailure) {
            return Center(child: Text('Ошибка: ${state.message}'));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;

  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(game.name),
      subtitle: Text('Игроков: ${game.players.length}/${game.maxPlayers}'),
      trailing: GameStatusChip(status: game.status),
    );
  }
}
