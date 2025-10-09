import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loreshifter/features/auth/auth_cubit.dart';
import 'package:loreshifter/features/auth/login_screen.dart';
import 'package:loreshifter/features/games/create_game_screen.dart';
import 'package:loreshifter/features/games/game_detail_screen.dart';
import 'package:loreshifter/features/games/game_screen.dart';
import 'package:loreshifter/features/home/home_screen.dart';
import 'package:loreshifter/features/profile/profile_screen.dart';

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
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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
          return EditWorldScreen(worldId: worldId);
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
          return GameDetailScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/games/code/:code',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return GameDetailScreen(code: code);
        },
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameScreen(),
      ),
    ],
    redirect: (context, state) async {
      // Проверка авторизации для защищенных путей
      final isAuthenticated = authCubit.state is Authenticated;
      final isAuthenticating = state.matchedLocation == '/login';

      // Защищенные маршруты
      final protectedPaths = [
        '/profile',
        '/worlds/create',
        '/worlds/*/edit',
        '/games/create',
        '/game',
      ];

      // Проверка, является ли текущий путь защищенным
      final isProtectedRoute = protectedPaths.any((path) {
        if (path.contains('*')) {
          final regex = RegExp(path.replaceAll('*', '[^/]+'));
          return regex.hasMatch(state.matchedLocation);
        }
        return state.matchedLocation == path;
      });

      // Если путь защищенный и пользователь не авторизован, перенаправляем на страницу входа
      if (isProtectedRoute && !isAuthenticated) {
        return '/login';
      }

      // Если пользователь авторизован и пытается попасть на страницу входа, перенаправляем на домашнюю страницу
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
