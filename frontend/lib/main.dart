import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/core/api/api_client.dart';
import '/core/router/app_router.dart';
import '/core/services/auth_service_impl.dart';
import '/core/services/world_service_impl.dart';
import '/core/services/game_service_impl.dart';
import '/core/services/gameplay_service_impl.dart';
import '/core/services/mocks/mock_auth_service.dart';
import '/core/services/mocks/mock_game_service.dart';
import '/core/services/mocks/mock_gameplay_service.dart';
import '/core/services/mocks/mock_world_service.dart';
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
    // Use mocks only in debug mode when explicitly requested
    final useMocks = kDebugMode && const bool.fromEnvironment('USE_MOCKS', defaultValue: false);
    
    final AuthService authService = useMocks
        ? MockAuthService(apiClient: apiClient)
        : AuthServiceImpl(apiClient: apiClient);
    
    final WorldService worldService = useMocks
        ? MockWorldService(apiClient: apiClient)
        : WorldServiceImpl(apiClient: apiClient);
    
    final GameService gameService = useMocks
        ? MockGameService(apiClient: apiClient)
        : GameServiceImpl(apiClient: apiClient);
    
    final GameplayService gameplayService = useMocks
        ? MockGameplayService()
        : GameplayServiceImpl(apiClient: apiClient);

    // Создаем кубиты
    final authCubit = AuthCubit(authService: authService);

    // Запускаем проверку авторизации при старте
    authCubit.checkAuth();

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
}
