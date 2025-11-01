import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/auth/auth_cubit.dart';
import '/core/theme/app_theme.dart';
import 'dart:developer' as developer;

/// Экран обработки OAuth колбэка после авторизации
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _statusMessage = 'АВТОРИЗАЦИЯ...';

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('🔐 AuthCallbackScreen: initState - начало обработки OAuth колбэка');
    developer.log('AuthCallbackScreen: initState - начало обработки OAuth колбэка');
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      // ignore: avoid_print
      print('🔐 AuthCallbackScreen: Ожидание установки cookies...');
      developer.log('AuthCallbackScreen: Ожидание установки cookies...');
      setState(() => _statusMessage = 'Ожидание cookies...');

      // Даем время на установку cookie от бэкенда
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        // ignore: avoid_print
        print('🔐 AuthCallbackScreen: Widget unmounted после задержки');
        developer.log('AuthCallbackScreen: Widget unmounted после задержки');
        return;
      }

      // ignore: avoid_print
      print('🔐 AuthCallbackScreen: Проверка авторизации...');
      developer.log('AuthCallbackScreen: Проверка авторизации...');
      setState(() => _statusMessage = 'Проверка авторизации...');

      // Проверяем авторизацию
      final authCubit = context.read<AuthCubit>();
      await authCubit.checkAuth();

      if (!mounted) {
        // ignore: avoid_print
        print('🔐 AuthCallbackScreen: Widget unmounted после checkAuth');
        developer.log('AuthCallbackScreen: Widget unmounted после checkAuth');
        return;
      }

      // Если авторизация успешна, перенаправляем на главную
      final state = authCubit.state;
      // ignore: avoid_print
      print('🔐 AuthCallbackScreen: Состояние авторизации: ${state.runtimeType}');
      developer.log('AuthCallbackScreen: Состояние авторизации: ${state.runtimeType}');

      if (state is Authenticated) {
        // ignore: avoid_print
        print('✅ AuthCallbackScreen: Авторизация успешна! Пользователь: ${state.user.name}');
        developer.log('AuthCallbackScreen: Авторизация успешна, редирект на главную');
        setState(() => _statusMessage = 'Успешно!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.go('/');
        }
      } else if (state is AuthFailure) {
        // ignore: avoid_print
        print('❌ AuthCallbackScreen: Ошибка авторизации: ${state.message}');
        developer.log('AuthCallbackScreen: Ошибка авторизации: ${state.message}');
        setState(() => _statusMessage = 'Ошибка: ${state.message}');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/login');
        }
      } else {
        // ignore: avoid_print
        print('⚠️ AuthCallbackScreen: Авторизация не удалась, редирект на login');
        developer.log('AuthCallbackScreen: Авторизация не удалась, редирект на login');
        setState(() => _statusMessage = 'Не авторизован');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('💥 AuthCallbackScreen: Критическая ошибка: $e');
      print(stackTrace);
      developer.log(
        'AuthCallbackScreen: Критическая ошибка',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _statusMessage = 'Ошибка: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.neonProgressIndicator(
              color: AppTheme.neonPurple,
              size: 60.0,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: AppTheme.neonTextStyle(
                color: AppTheme.neonPurple,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
