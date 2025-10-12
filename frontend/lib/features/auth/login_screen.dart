import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/auth/auth_cubit.dart';
import '/core/theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Используем наши цвета для фона
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'LORESHIFTER',
          style: AppTheme.neonTextStyle(
            color: AppTheme.neonBlue,
            fontSize: 22.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                children: [
                  // Неоновый логотип
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.darkSurface,
                      boxShadow: AppTheme.neonShadow(AppTheme.neonPurple),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      size: 70,
                      color: AppTheme.neonPurple,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Заголовок с градиентом
                  AppTheme.gradientText(
                    text: 'LORESHIFTER',
                    gradient: AppTheme.purpleToPinkGradient,
                    fontSize: 36.0,
                    fontWeight: FontWeight.bold,
                  ),

                  const SizedBox(height: 16),

                  // Описание в неоновом контейнере
                  AppTheme.neonContainer(
                    borderColor: AppTheme.neonGreen,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Платформа для создания и исследования виртуальных миров с помощью генеративной LLM',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 48),

                  if (state is AuthLoading)
                    // Неоновый индикатор загрузки
                    AppTheme.neonProgressIndicator(
                      color: AppTheme.neonBlue,
                      size: 50.0,
                    )
                  else
                    Column(
                      children: [
                        // Анимированная неоновая кнопка для входа
                        AppTheme.animatedNeonButton(
                          text: 'ВОЙТИ ЧЕРЕЗ GOOGLE',
                          onPressed: () {
                            // В MVP открываем URL для авторизации
                            final loginUrl =
                                context.read<AuthCubit>().getLoginUrl();
                            // В реальном приложении надо бы настроить OAuth2
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Перенаправление на $loginUrl'),
                                backgroundColor: AppTheme.darkAccent,
                              ),
                            );

                            // Для MVP просто имитируем успешную авторизацию
                            context.read<AuthCubit>().checkAuth();
                          },
                          color: AppTheme.neonBlue,
                        ),

                        const SizedBox(height: 24),

                        // Неоновый разделитель
                        AppTheme.neonDivider(
                          color: AppTheme.neonPurple,
                          indent: 50,
                          endIndent: 50,
                        ),

                        const SizedBox(height: 24),

                        // Кнопка для продолжения без авторизации
                        InkWell(
                          onTap: () {
                            context.go('/');
                          },
                          child: Text(
                            'ПРОДОЛЖИТЬ БЕЗ АВТОРИЗАЦИИ',
                            style: AppTheme.neonTextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (state is AuthFailure)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: AppTheme.neonContainer(
                        borderColor: AppTheme.neonPink,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'ОШИБКА: ${state.message}',
                          style: TextStyle(
                            color: AppTheme.neonPink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
