import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/features/auth/auth_cubit.dart';
import '/features/auth/login_screen.dart';
import '/features/auth/auth_callback_screen.dart';
import '/features/games/create_game_screen.dart';
import '/features/games/game_lobby_screen.dart';
import '/features/games/game_screen.dart';
import '/features/home/home_screen.dart';
import '/features/profile/profile_screen.dart';
import '/features/history/user_history_screen.dart';
import '/features/history/world_history_screen.dart';

import '../../features/worlds/create_world_screen.dart';
import '../../features/worlds/edit_world_screen.dart';
import '../../features/worlds/world_detail_screen.dart';

class AppRouter {
  final AuthCubit authCubit;

  AppRouter(this.authCubit);

  late final router = GoRouter(
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final tabIndex = int.tryParse(tabParam ?? '') ?? 0;
          return HomeScreen(initialTabIndex: tabIndex);
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = int.parse(state.pathParameters['userId']!);
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // История игр пользователя
      GoRoute(
        path: '/history/:userId',
        builder: (context, state) {
          final userId = int.parse(state.pathParameters['userId']!);
          return UserHistoryScreen(userId: userId);
        },
      ),
      // История конкретного мира
      GoRoute(
        path: '/worlds/:worldId/history',
        builder: (context, state) {
          final worldId = int.parse(state.pathParameters['worldId']!);
          return WorldHistoryScreen(worldId: worldId);
        },
      ),
      GoRoute(
        path: '/worlds/create',
        builder: (context, state) => const CreateWorldScreen(),
      ),
      GoRoute(
        path: '/worlds/:worldId',
        builder: (context, state) {
          final worldId = int.parse(state.pathParameters['worldId']!);
          return WorldDetailScreen(worldId: worldId);
        },
      ),
      GoRoute(
        path: '/worlds/:worldId/edit',
        builder: (context, state) {
          final worldId = int.parse(state.pathParameters['worldId']!);
          final sourceWorldId = state.uri.queryParameters['sourceWorldId'];
          final isFreshCopy = state.uri.queryParameters['isFreshCopy'] == 'true';
          return EditWorldScreen(
            worldId: worldId,
            sourceWorldId: sourceWorldId != null ? int.parse(sourceWorldId) : null,
            isFreshCopy: isFreshCopy,
          );
        },
      ),
      GoRoute(
        path: '/games/create',
        builder: (context, state) {
          final worldId = state.uri.queryParameters['worldId'];
          return CreateGameScreen(
            worldId: worldId != null ? int.parse(worldId) : null,
          );
        },
      ),
      GoRoute(
        path: '/games/:gameId',
        builder: (context, state) {
          final gameId = int.parse(state.pathParameters['gameId']!);
          return GameLobbyScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/games/code/:code',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return GameLobbyScreen(code: code);
        },
      ),
      // Экран игры с параметром gameId
      GoRoute(
        path: '/game/:gameId',
        builder: (context, state) {
          final gameId = int.parse(state.pathParameters['gameId']!);
          return GameScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
    ],
    redirect: (context, state) async {
      // Проверка авторизации для защищенных путей
      final isAuthenticated = authCubit.state is Authenticated;
      final isAuthenticating = state.matchedLocation == '/login';

      final loc = state.matchedLocation;

      // Защищенные маршруты
      final isProtectedRoute =
          loc == '/profile' ||
          loc.startsWith('/history/') ||
          loc == '/worlds/create' ||
          RegExp(r'^/worlds/[^/]+/edit$').hasMatch(loc) ||
          loc == '/games/create' ||
          RegExp(r'^/game/[^/]+/?$').hasMatch(loc);

      if (isProtectedRoute && !isAuthenticated) {
        return '/login';
      }

      if (isAuthenticating && isAuthenticated) {
        return '/';
      }

      return null;
    },
  );
}

// Класс для отслеживания изменений состояния авторизации
class GoRouterRefreshStream extends ChangeNotifier {
  final Stream<dynamic> stream;
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(this.stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
