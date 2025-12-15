import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/core/api/api_client.dart';
import '/core/router/app_router.dart';
import '/core/services/auth_service_impl.dart';
import '/core/services/mocks/mock_auth_service.dart';
import '/core/services/mocks/mock_game_service.dart';
import '/core/services/mocks/mock_gameplay_service.dart';
import '/core/services/mocks/mock_world_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '/features/auth/auth_cubit.dart';
import '/features/chat/gameplay_cubit.dart';
import '/features/games/games_cubit.dart';
import '/features/worlds/worlds_cubit.dart';
import '/core/services/interfaces/auth_service_interface.dart';
import '/core/services/interfaces/world_service_interface.dart';
import '/core/services/interfaces/game_service_interface.dart';
import '/core/services/interfaces/gameplay_service_interface.dart';

import 'core/theme/app_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // Создаем ApiClient с локальным URL бекенда для разработки
  final apiClient = ApiClient(baseUrl: const String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8000/api/v0'
  ));

  @override
  Widget build(BuildContext context) {
    final useMockAuth = const bool.fromEnvironment('USE_MOCK_AUTH', defaultValue: true);
    
    final AuthService authService = useMockAuth 
        ? MockAuthService(apiClient: apiClient)
        : AuthServiceImpl(apiClient: apiClient);
    
    final worldService = MockWorldService(apiClient: apiClient);
    final gameService = MockGameService(apiClient: apiClient);
    final gameplayService = MockGameplayService();

    // Создаем кубиты
    final authCubit = AuthCubit(authService: authService);

    // Запускаем проверку авторизации при старте
    authCubit.checkAuth();
    
    if (!useMockAuth && kDebugMode) {
      _tryTestLogin(authService as AuthServiceImpl);
    }

    // Настраиваем маршрутизацию
    final appRouter = AppRouter(authCubit);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<WorldService>.value(value: worldService),
        RepositoryProvider<GameService>.value(value: gameService),
        RepositoryProvider<GameplayService>.value(value: gameplayService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(create: (_) => authCubit),
          BlocProvider<WorldsCubit>(
            create: (_) => WorldsCubit(worldService: worldService),
          ),
          BlocProvider<GamesCubit>(
            create: (_) => GamesCubit(gameService: gameService),
          ),
          BlocProvider<GameplayCubit>(
            create: (_) => GameplayCubit(gameplayService: gameplayService),
          ),
        ],
        child: MaterialApp.router(
          title: 'Loreshifter',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system, // Автоматически выбирает тему по системным настройкам
          routerConfig: appRouter.router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }

  /// Пытается выполнить тестовый вход, если бэкенд доступен
  void _tryTestLogin(AuthServiceImpl authService) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await authService.testLogin(username: 'Test User', email: 'test@example.com');
        debugPrint('✅ Тестовый вход выполнен успешно');
      } catch (e) {
        debugPrint('⚠️ Тестовый вход не удался (возможно, бэкенд не запущен): $e');
      }
    });
  }
}
