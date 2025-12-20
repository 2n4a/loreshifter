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
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockUser;
  }

  // Получить данные пользователя по id
  @override
  Future<User> getUserById(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));

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
    await Future.delayed(const Duration(milliseconds: 100));
    return true; // Для демо всегда считаем, что пользователь авторизован
  }

  // URL для авторизации (заглушка)
  @override
  Future<String> getLoginUrl({String? provider}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return "${apiClient.baseUrl}/login?provider=${provider ?? 'github'}";
  }

  // Создать временного пользователя (в моке просто эмулируем задержку)
  @override
  Future<void> testLogin({String? name, String? email}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // В реальной реализации здесь устанавливается cookie
  }

  // Выход из системы
  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Заглушка - ничего не делаем
  }
}
