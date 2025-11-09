import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/auth/auth_cubit.dart';
import 'dart:developer' as developer;

/// Экран обработки OAuth колбэка после авторизации
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _statusMessage = 'Авторизация...';

  @override
  void initState() {
    super.initState();
    developer.log('AuthCallbackScreen: initState - начало обработки OAuth колбэка');
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      developer.log('AuthCallbackScreen: Ожидание установки cookies...');
      setState(() => _statusMessage = 'Ожидание cookies...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      developer.log('AuthCallbackScreen: Проверка авторизации...');
      setState(() => _statusMessage = 'Проверка авторизации...');
      final authCubit = context.read<AuthCubit>();
      await authCubit.checkAuth();
      if (!mounted) return;

      final state = authCubit.state;
      developer.log('AuthCallbackScreen: Состояние авторизации: ${state.runtimeType}');
      if (state is Authenticated) {
        setState(() => _statusMessage = 'Успешно!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.go('/');
      } else if (state is AuthFailure) {
        setState(() => _statusMessage = 'Ошибка: ${state.message}');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      } else {
        setState(() => _statusMessage = 'Не авторизован');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
    } catch (e, stackTrace) {
      developer.log('AuthCallbackScreen: Критическая ошибка', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _statusMessage = 'Ошибка: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60, height: 60, child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
