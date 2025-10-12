import '/features/auth/domain/models/user.dart';

/// Интерфейс для сервиса аутентификации
abstract class AuthService {
  /// Получить данные текущего пользователя
  Future<User> getCurrentUser();

  /// Получить данные пользователя по id
  Future<User> getUserById(int id);

  /// Обновить данные текущего пользователя
  Future<User> updateUser(String name);

  /// Проверка авторизации
  Future<bool> isAuthenticated();

  /// URL для авторизации
  String getLoginUrl();
}
