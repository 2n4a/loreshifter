import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/features/auth/domain/models/user.dart';
import '/core/services/interfaces/auth_service_interface.dart';
import 'dart:developer' as developer;

// Состояния аутентификации
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;

  Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// Кубит аутентификации
class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  AuthCubit({required AuthService authService})
    : _authService = authService,
      super(AuthInitial());

  // Проверить аутентификацию
  Future<void> checkAuth() async {
    // ignore: avoid_print
    print('🔑 AuthCubit: Начало проверки авторизации');
    developer.log('AuthCubit: Начало проверки авторизации');
    emit(AuthLoading());
    try {
      // ignore: avoid_print
      print('🔑 AuthCubit: Вызов isAuthenticated()');
      developer.log('AuthCubit: Вызов isAuthenticated()');
      final isAuth = await _authService.isAuthenticated();
      // ignore: avoid_print
      print('🔑 AuthCubit: isAuthenticated() = $isAuth');
      developer.log('AuthCubit: isAuthenticated() = $isAuth');

      if (isAuth) {
        // ignore: avoid_print
        print('🔑 AuthCubit: Получение данных пользователя');
        developer.log('AuthCubit: Получение данных пользователя');
        final user = await _authService.getCurrentUser();
        // ignore: avoid_print
        print(
          '✅ AuthCubit: Пользователь получен - id: ${user.id}, name: ${user.name}',
        );
        developer.log(
          'AuthCubit: Пользователь получен - id: ${user.id}, name: ${user.name}',
        );
        emit(Authenticated(user));
      } else {
        // ignore: avoid_print
        print('⚠️ AuthCubit: Пользователь не авторизован');
        developer.log('AuthCubit: Пользователь не авторизован');
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ AuthCubit: Ошибка при проверке авторизации: $e');
      developer.log(
        'AuthCubit: Ошибка при проверке авторизации',
        error: e,
        stackTrace: stackTrace,
      );
      emit(AuthFailure(e.toString()));
    }
  }

  // Получить URL для входа
  Future<String> getLoginUrl({String? provider}) async {
    final url = await _authService.getLoginUrl(provider: provider);
    // ignore: avoid_print
    print('🔗 AuthCubit: URL для входа: $url');
    developer.log('AuthCubit: URL для входа: $url');
    return url;
  }

  // Создать временного пользователя
  Future<void> testLogin({String? name, String? email}) async {
    // ignore: avoid_print
    print('🧪 AuthCubit: Создание временного пользователя');
    developer.log('AuthCubit: Создание временного пользователя');
    emit(AuthLoading());
    try {
      await _authService.testLogin(name: name, email: email);
      // ignore: avoid_print
      print('✅ AuthCubit: Временный пользователь создан, проверка авторизации');
      developer.log('AuthCubit: Временный пользователь создан, проверка авторизации');
      // После создания временного пользователя проверяем авторизацию
      await checkAuth();
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ AuthCubit: Ошибка при создании временного пользователя: $e');
      developer.log('AuthCubit: Ошибка при создании временного пользователя', error: e, stackTrace: stackTrace);
      emit(AuthFailure(e.toString()));
    }
  }

  // Выход из аккаунта
  Future<void> logout() async {
    // ignore: avoid_print
    print('👋 AuthCubit: Выход из системы');
    developer.log('AuthCubit: Выход из системы');
    emit(AuthLoading());
    try {
      await _authService.logout();
      // ignore: avoid_print
      print('✅ AuthCubit: Выход успешен');
      developer.log('AuthCubit: Выход успешен');
      emit(Unauthenticated());
    } catch (e) {
      // ignore: avoid_print
      print('❌ AuthCubit: Ошибка при выходе: $e');
      developer.log('AuthCubit: Ошибка при выходе', error: e);
      emit(AuthFailure(e.toString()));
    }
  }

  // Обновить данные пользователя
  Future<void> updateUserName(String name) async {
    // ignore: avoid_print
    print('📝 AuthCubit: Обновление имени пользователя на: $name');
    developer.log('AuthCubit: Обновление имени пользователя на: $name');
    final currentState = state;
    if (currentState is Authenticated) {
      try {
        final updatedUser = await _authService.updateUser(name);
        // ignore: avoid_print
        print('✅ AuthCubit: Имя пользователя обновлено');
        developer.log('AuthCubit: Имя пользователя обновлено');
        emit(Authenticated(updatedUser));
      } catch (e) {
        // ignore: avoid_print
        print('❌ AuthCubit: Ошибка при обновлении имени: $e');
        developer.log('AuthCubit: Ошибка при обновлении имени', error: e);
        emit(AuthFailure(e.toString()));
      }
    }
  }
}
