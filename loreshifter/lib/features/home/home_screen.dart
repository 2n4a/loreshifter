import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/world.dart';
import 'package:loreshifter/features/auth/auth_cubit.dart';
import 'package:loreshifter/features/games/games_cubit.dart';
import 'package:loreshifter/features/worlds/worlds_cubit.dart';
import 'package:loreshifter/core/theme/app_theme.dart';
import 'package:loreshifter/core/widgets/game_status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Загружаем данные при инициализации экрана
    _loadInitialData();
  }

  void _loadInitialData() {
    // Загружаем список активных игр
    context.read<GamesCubit>().loadGames();

    // Загружаем популярные миры для витрины
    context.read<WorldsCubit>().loadPopularWorlds();

    // Если пользователь авторизован, загружаем его миры
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkAccent,
        title: AppTheme.gradientText(
          text: 'LORESHIFTER',
          gradient: AppTheme.neonGradient,
          fontSize: 22.0,
        ),
        elevation: 0,
        actions: [_buildHistoryButton(), _buildProfileButton()],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: AppTheme.greenToBlueGradient,
            borderRadius: BorderRadius.circular(10.0),
          ),
          labelColor: AppTheme.neonGreen,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'КОМНАТЫ'),
            Tab(text: 'МОИ МИРЫ'),
            Tab(text: 'ВИТРИНА'),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppTheme.neonShadow(AppTheme.neonPink),
        ),
        child: FloatingActionButton(
          backgroundColor: AppTheme.darkSurface,
          onPressed: () => context.push('/worlds/create'),
          tooltip: 'Создать мир',
          child: Icon(Icons.add, color: AppTheme.neonPink, size: 30),
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppTheme.neonShadow(AppTheme.neonBlue),
            ),
            child: IconButton(
              icon: Icon(Icons.account_circle, color: AppTheme.neonBlue),
              onPressed: () => context.push('/profile'),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.neonShadow(AppTheme.neonGreen),
          ),
          child: TextButton(
            onPressed: () => context.push('/login'),
            child: Text(
              'ВОЙТИ',
              style: AppTheme.neonTextStyle(
                color: AppTheme.neonGreen,
                fontSize: 14.0,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryButton() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          final userId = state.user.id;
          return Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppTheme.neonShadow(AppTheme.neonPurple),
            ),
            child: IconButton(
              icon: Icon(Icons.history, color: AppTheme.neonPurple),
              tooltip: 'История игр',
              onPressed: () => context.push('/history/$userId'),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Вкладка "Доступные комнаты" показывает список активных игр
  Widget _buildAvailableRooms() {
    return BlocBuilder<GamesCubit, GamesState>(
      builder: (context, state) {
        if (state is GamesLoading) {
          return Center(
            child: AppTheme.neonProgressIndicator(
              color: AppTheme.neonBlue,
              size: 50.0,
            ),
          );
        }

        if (state is GamesLoaded) {
          final games = state.games;

          if (games.isEmpty) {
            return Center(
              child: Container(
                width: 300,
                child: AppTheme.neonContainer(
                  borderColor: AppTheme.neonPurple,
                  child: const Text(
                    'АКТИВНЫХ КОМНАТ НЕ НАЙДЕНО',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _buildGameCard(game);
            },
          );
        }

        if (state is GamesFailure) {
          return Center(
            child: Container(
              width: 300,
              child: AppTheme.neonContainer(
                borderColor: AppTheme.neonPink,
                child: Text(
                  'ОШИБКА: ${state.message}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.neonPink),
                ),
              ),
            ),
          );
        }

        return Center(
          child: Container(
            width: 300,
            child: AppTheme.neonContainer(
              borderColor: AppTheme.neonGreen,
              child: const Text(
                'ЗАГРУЗИТЕ СПИСОК КОМНАТ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  // Карточка комнаты/игры
  Widget _buildGameCard(Game game) {
    return AppTheme.neonCard(
      title: game.name,
      borderColor: AppTheme.neonBlue,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.push('/games/${game.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'МИР: ${game.world.name}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                GameStatusChip(status: game.status, uppercase: true),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'ИГРОКОВ: ${game.players.length}/${game.maxPlayers}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppTheme.neonButton(
                  text: 'ЗАЙТИ',
                  onPressed: () {
                    // Просто переходим на экран деталей, без вызова joinGame
                    context.push('/games/${game.id}');
                  },
                  color: AppTheme.neonGreen,
                  width: 120.0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Вкладка "Мои миры"
  Widget _buildMyWorlds() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (authState is Unauthenticated) {
          return Center(
            child: Container(
              width: 300,
              child: AppTheme.neonContainer(
                borderColor: AppTheme.neonPurple,
                child: const Text(
                  'ВОЙДИТЕ, ЧТОБЫ УВИДЕТЬ СВОИ МИРЫ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return BlocBuilder<WorldsCubit, WorldsState>(
          builder: (context, state) {
            if (state is WorldsLoading) {
              return Center(
                child: AppTheme.neonProgressIndicator(
                  color: AppTheme.neonPurple,
                  size: 50.0,
                ),
              );
            }

            if (state is UserWorldsLoaded) {
              final worlds = state.worlds;

              if (worlds.isEmpty) {
                return Center(
                  child: Container(
                    width: 300,
                    child: AppTheme.neonContainer(
                      borderColor: AppTheme.neonGreen,
                      child: const Text(
                        'У ВАС ПОКА НЕТ СОЗДАННЫХ МИРОВ',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: worlds.length,
                itemBuilder: (context, index) {
                  final world = worlds[index];
                  return _buildWorldCard(world, isMyWorld: true);
                },
              );
            }

            if (state is WorldsFailure) {
              return Center(
                child: Container(
                  width: 300,
                  child: AppTheme.neonContainer(
                    borderColor: AppTheme.neonPink,
                    child: Text(
                      'ОШИБКА: ${state.message}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.neonPink),
                    ),
                  ),
                ),
              );
            }

            return Center(
              child: Container(
                width: 300,
                child: AppTheme.neonContainer(
                  borderColor: AppTheme.neonGreen,
                  child: const Text(
                    'АВТОРИЗУЙТЕСЬ, ЧТОБЫ УВИДЕТЬ СВОИ МИРЫ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Вкладка "Витрина миров"
  Widget _buildWorldsShowcase() {
    return BlocBuilder<WorldsCubit, WorldsState>(
      builder: (context, state) {
        if (state is WorldsLoading) {
          return Center(
            child: AppTheme.neonProgressIndicator(
              color: AppTheme.neonGreen,
              size: 50.0,
            ),
          );
        }

        if (state is PopularWorldsLoaded) {
          final worlds = state.worlds;

          if (worlds.isEmpty) {
            return Center(
              child: Container(
                width: 300,
                child: AppTheme.neonContainer(
                  borderColor: AppTheme.neonPurple,
                  child: const Text(
                    'МИРЫ НЕ НАЙДЕНЫ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: worlds.length,
            itemBuilder: (context, index) {
              final world = worlds[index];
              return _buildWorldCard(world, isMyWorld: false);
            },
          );
        }

        if (state is WorldsFailure) {
          return Center(
            child: Container(
              width: 300,
              child: AppTheme.neonContainer(
                borderColor: AppTheme.neonPink,
                child: Text(
                  'ОШИБКА: ${state.message}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.neonPink),
                ),
              ),
            ),
          );
        }

        return Center(
          child: Container(
            width: 300,
            child: AppTheme.neonContainer(
              borderColor: AppTheme.neonGreen,
              child: const Text(
                'ЗАГРУЗКА МИРОВ...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  // Карточка мира
  Widget _buildWorldCard(World world, {required bool isMyWorld}) {
    // Определяем цвет в зависимости от типа мира
    Color borderColor;
    switch (world.type) {
      case WorldType.fantasy:
        borderColor = AppTheme.neonPurple;
        break;
      case WorldType.scifi:
        borderColor = AppTheme.neonBlue;
        break;
      case WorldType.historical:
        borderColor = AppTheme.neonPink;
        break;
      case WorldType.horror:
        borderColor = Colors.red;
        break;
      default:
        borderColor = AppTheme.neonGreen;
    }

    return AppTheme.neonContainer(
      borderColor: borderColor,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/worlds/${world.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок с градиентом
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.darkAccent,
                    Color.lerp(AppTheme.darkAccent, borderColor, 0.3)!,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Text(
                world.name.toUpperCase(),
                style: TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Содержимое карточки
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ТИП: ${world.type.toString().split('.').last.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      world.description ?? 'Нет описания',
                      // Добавляем проверку на null
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'РЕЙТИНГ: ${world.rating}/10',
                          style: TextStyle(
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMyWorld)
                          Icon(Icons.edit, color: borderColor, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Кнопка действия
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    borderColor.withAlpha(100),
                    borderColor.withAlpha(50),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: MaterialButton(
                onPressed: () {
                  if (isMyWorld) {
                    context.push('/games/create?worldId=${world.id}');
                  } else {
                    context.push('/worlds/${world.id}');
                  }
                },
                child: Text(
                  isMyWorld ? 'СОЗДАТЬ ИГРУ' : 'ПОДРОБНЕЕ',
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
