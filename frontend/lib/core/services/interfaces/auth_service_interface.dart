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

  /// Получить URL для OAuth2 авторизации
  Future<String> getLoginUrl({String? provider});

  /// Создать временного пользователя для тестирования (устанавливает cookie)
  Future<void> testLogin({String? name, String? email});

  /// Выход из системы
  Future<void> logout();
}
