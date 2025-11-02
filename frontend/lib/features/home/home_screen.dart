import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/games/domain/models/game.dart';
import '/features/worlds/domain/models/world.dart';
import '/features/auth/auth_cubit.dart';
import '/features/games/games_cubit.dart';
import '/features/worlds/worlds_cubit.dart';
import '/core/widgets/modern_card.dart';
import '/core/widgets/neon_button.dart';
import '/features/games/presentation/widgets/game_status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _initialTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    final tabParam = uri.queryParameters['tab'];
    _initialTabIndex = int.tryParse(tabParam ?? '') ?? 0;
    if (_initialTabIndex < 0 || _initialTabIndex > 2) _initialTabIndex = 0;

    _tabController = TabController(length: 3, vsync: this, initialIndex: _initialTabIndex);
    _loadInitialData();
  }

  void _loadInitialData() {
    context.read<GamesCubit>().loadGames();
    context.read<WorldsCubit>().loadPopularWorlds();
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      context.read<WorldsCubit>().loadUserWorlds(authState.user.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loreshifter'),
        actions: [_buildHistoryButton(), _buildProfileButton()],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(10.0),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: cs.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Комнаты'),
            Tab(text: 'Мои миры'),
            Tab(text: 'Витрина'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableRooms(),
          _buildMyWorlds(),
          _buildWorldsShowcase(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/worlds/create'),
        tooltip: 'Создать мир',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProfileButton() {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return IconButton(
            icon: const Icon(Icons.account_circle),
            color: cs.primary,
            onPressed: () => context.push('/profile'),
          );
        }
        return TextButton(
          onPressed: () => context.push('/login'),
          child: const Text('Войти'),
        );
      },
    );
  }

  Widget _buildHistoryButton() {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          final userId = state.user.id;
          return IconButton(
            icon: const Icon(Icons.history),
            color: cs.secondary,
            tooltip: 'История игр',
            onPressed: () => context.push('/history/$userId'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _emptyCard(String text) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ModernCard(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  // Вкладка "Доступные комнаты"
  Widget _buildAvailableRooms() {
    return BlocBuilder<GamesCubit, GamesState>(
      builder: (context, state) {
        if (state is GamesLoading) return _loading();

        if (state is GamesLoaded) {
          final games = state.games;
          if (games.isEmpty) return _emptyCard('Активных комнат не найдено');

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _buildGameCard(game);
            },
          );
        }

        if (state is GamesFailure) {
          return _emptyCard('Ошибка: ${state.message}');
        }

        return _emptyCard('Загрузите список комнат');
      },
    );
  }

  Widget _buildGameCard(Game game) {
    final cs = Theme.of(context).colorScheme;
    return ModernCard(
      child: InkWell(
        onTap: () => context.push('/games/${game.id}'),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  GameStatusChip(status: game.status, uppercase: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Мир: ${game.world.name}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Игроков: ${game.players.length}/${game.maxPlayers}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeonButton(
                    text: 'Зайти',
                    onPressed: () => context.push('/games/${game.id}'),
                    style: NeonButtonStyle.filled,
                    color: cs.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Вкладка "Мои миры"
  Widget _buildMyWorlds() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (authState is Unauthenticated) {
          return _emptyCard('Войдите, чтобы увидеть свои миры');
        }

        return BlocBuilder<WorldsCubit, WorldsState>(
          builder: (context, state) {
            if (state is WorldsLoading) return _loading();

            if (state is UserWorldsLoaded) {
              final worlds = state.worlds;
              if (worlds.isEmpty) return _emptyCard('У вас пока нет созданных миров');

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: worlds.length,
                itemBuilder: (context, index) {
                  final world = worlds[index];
                  return _buildWorldCard(world, isMyWorld: true);
                },
              );
            }

            if (state is WorldsFailure) {
              return _emptyCard('Ошибка: ${state.message}');
            }

            return _emptyCard('Авторизуйтесь, чтобы увидеть свои миры');
          },
        );
      },
    );
  }

  // Вкладка "Витрина миров"
  Widget _buildWorldsShowcase() {
    return BlocBuilder<WorldsCubit, WorldsState>(
      builder: (context, state) {
        if (state is WorldsLoading) return _loading();

        if (state is PopularWorldsLoaded) {
          final worlds = state.worlds;
          if (worlds.isEmpty) return _emptyCard('Миры не найдены');

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: worlds.length,
            itemBuilder: (context, index) {
              final world = worlds[index];
              return _buildWorldCard(world, isMyWorld: false);
            },
          );
        }

        if (state is WorldsFailure) {
          return _emptyCard('Ошибка: ${state.message}');
        }

        return _emptyCard('Загрузка миров...');
      },
    );
  }

  Widget _buildWorldCard(World world, {required bool isMyWorld}) {
    final cs = Theme.of(context).colorScheme;
    return ModernCard(
      child: InkWell(
        onTap: () => context.push('/worlds/${world.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(
                world.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тип: ${world.type.toString().split('.').last}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      world.description ?? 'Нет описания',
                      style: TextStyle(color: cs.onSurface, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Рейтинг: ${world.rating}/10',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                        ),
                        if (isMyWorld)
                          Icon(Icons.edit, color: cs.onSurfaceVariant, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: TextButton(
                onPressed: () {
                  if (isMyWorld) {
                    context.push('/games/create?worldId=${world.id}');
                  } else {
                    context.push('/worlds/${world.id}');
                  }
                },
                child: Text(isMyWorld ? 'Создать игру' : 'Подробнее'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
