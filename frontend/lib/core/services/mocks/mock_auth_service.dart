import '/features/auth/domain/models/user.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/auth_service_interface.dart';

/// Заглушка для сервиса аутентификации
class MockAuthService extends BaseService implements AuthService {
  MockAuthService({required super.apiClient});

  // Фиктивный пользователь (как будто авторизован)
  final User _mockUser = User(
    id: 1,
    name: "Тестовый пользователь",
    email: "test@example.com",
  );

  // Получить данные текущего пользователя
  @override
  Future<User> getCurrentUser() async {
    // Эмулируем задержку сети
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockUser;
  }

  // Получить данные пользователя по id
  @override
  Future<User> getUserById(int id) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (id == 1) return _mockUser;

    return User(id: id, name: "Пользователь $id");
  }

  // Обновить данные текущего пользователя
  @override
  Future<User> updateUser(String name) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return User(id: _mockUser.id, name: name, email: _mockUser.email);
  }

  // Проверка авторизации
  @override
  Future<bool> isAuthenticated() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // Для демо всегда считаем, что пользователь авторизован
  }

  // URL для авторизации (заглушка)
  @override
  String getLoginUrl() {
    return "${apiClient.baseUrl}/login";
  }
}
