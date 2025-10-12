import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/core/api/api_client.dart';
import '/core/router/app_router.dart';
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

  // Создаем ApiClient (хотя на самом деле он не будет использоваться для запросов)
  final apiClient = ApiClient(baseUrl: 'https://ls.elteammate.space/api/v0');

  @override
  Widget build(BuildContext context) {
    // Создаем МОКОВЫЕ сервисы вместо реальных
    final authService = MockAuthService(apiClient: apiClient);
    final worldService = MockWorldService(apiClient: apiClient);
    final gameService = MockGameService(apiClient: apiClient);
    final gameplayService = MockGameplayService(); // Убираю параметр apiClient

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
          theme: AppTheme.darkTheme,
          // Применяем киберпанк-тему
          routerConfig: appRouter.router,
          // Добавляем обязательный параметр конфигурации роутера
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
