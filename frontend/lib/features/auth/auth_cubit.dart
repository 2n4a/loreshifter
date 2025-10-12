import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/features/auth/domain/models/user.dart';
import '/core/services/interfaces/auth_service_interface.dart';

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
    emit(AuthLoading());
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final user = await _authService.getCurrentUser();
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // Получить URL для входа
  String getLoginUrl() {
    return _authService.getLoginUrl();
  }

  // Выход из аккаунта
  Future<void> logout() async {
    emit(AuthLoading());
    try {
      // Здесь должен быть вызов _authService.logout(), но в MVP он не реализован
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // Обновить данные пользователя
  Future<void> updateUserName(String name) async {
    final currentState = state;
    if (currentState is Authenticated) {
      try {
        final updatedUser = await _authService.updateUser(name);
        emit(Authenticated(updatedUser));
      } catch (e) {
        // В случае ошибки возвращаемся к предыдущему состоянию
        emit(currentState);
        emit(AuthFailure(e.toString()));
      }
    }
  }
}
