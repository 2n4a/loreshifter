import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import '/features/auth/auth_cubit.dart';
import '/core/widgets/neon_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _handleLogin(BuildContext context, String provider) async {
    final loginUrl = context.read<AuthCubit>().getLoginUrl(provider: provider);

    if (kIsWeb) {
      web.window.location.href = await loginUrl;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Авторизация доступна только в веб-версии'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Loreshifter')),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            context.go('/');
          }
        },
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 40,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loreshifter',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Текстовые новеллы и миры на базе LLM',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (state is AuthLoading)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    NeonButton(
                      text: 'Войти через GitHub',
                      icon: Icons.login,
                      onPressed: () => _handleLogin(context, 'github'),
                      style: NeonButtonStyle.filled,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.read<AuthCubit>().testLogin(),
                      child: const Text('Продолжить со временным аккаунтом'),
                    ),
                  ],
                  if (state is AuthFailure) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка: ${state.message}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
