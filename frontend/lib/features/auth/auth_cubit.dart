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
    developer.log('[CUBIT:AUTH] checkAuth() started');
    emit(AuthLoading());
    try {
      final isAuth = await _authService.isAuthenticated();
      developer.log('[CUBIT:AUTH] checkAuth() isAuthenticated=$isAuth');

      if (isAuth) {
        final user = await _authService.getCurrentUser();
        developer.log('[CUBIT:AUTH] checkAuth() -> Authenticated(user.id=${user.id})');
        emit(Authenticated(user));
      } else {
        developer.log('[CUBIT:AUTH] checkAuth() -> Unauthenticated');
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      developer.log('[CUBIT:AUTH] checkAuth() -> Error', error: e, stackTrace: stackTrace);
      emit(AuthFailure(e.toString()));
    }
  }

  // Получить URL для входа
  Future<String> getLoginUrl({String? provider}) async {
    developer.log('[CUBIT:AUTH] getLoginUrl(provider=$provider)');
    final url = await _authService.getLoginUrl(provider: provider);
    developer.log('[CUBIT:AUTH] getLoginUrl() -> $url');
    return url;
  }

  // Создать временного пользователя
  Future<void> testLogin({String? name, String? email}) async {
    developer.log('[CUBIT:AUTH] testLogin(name=$name, email=$email) started');
    emit(AuthLoading());
    try {
      await _authService.testLogin(name: name, email: email);
      developer.log('[CUBIT:AUTH] testLogin() -> checking auth');
      await checkAuth();
    } catch (e, stackTrace) {
      developer.log('[CUBIT:AUTH] testLogin() -> Error', error: e, stackTrace: stackTrace);
      emit(AuthFailure(e.toString()));
    }
  }

  // Выход из аккаунта
  Future<void> logout() async {
    developer.log('[CUBIT:AUTH] logout() started');
    emit(AuthLoading());
    try {
      await _authService.logout();
      developer.log('[CUBIT:AUTH] logout() -> Unauthenticated');
      emit(Unauthenticated());
    } catch (e) {
      developer.log('[CUBIT:AUTH] logout() -> Error', error: e);
      emit(AuthFailure(e.toString()));
    }
  }

  // Обновить данные пользователя
  Future<void> updateUserName(String name) async {
    developer.log('[CUBIT:AUTH] updateUserName(name=$name) started');
    final currentState = state;
    if (currentState is Authenticated) {
      try {
        final updatedUser = await _authService.updateUser(name);
        developer.log('[CUBIT:AUTH] updateUserName() -> Success');
        emit(Authenticated(updatedUser));
      } catch (e) {
        developer.log('[CUBIT:AUTH] updateUserName() -> Error', error: e);
        emit(AuthFailure(e.toString()));
      }
    }
  }
}
