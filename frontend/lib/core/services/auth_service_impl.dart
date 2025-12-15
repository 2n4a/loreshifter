import '/features/auth/domain/models/user.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/auth_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса аутентификации
class AuthServiceImpl extends BaseService implements AuthService {
  AuthServiceImpl({required super.apiClient});

  @override
  Future<User> getCurrentUser() async {
    developer.log('AuthService: Запрос текущего пользователя GET /user/me');
    try {
      final user = await apiClient.get<User>(
        '/user/me',
        fromJson: (data) => User.fromJson(data),
      );
      developer.log('AuthService: Пользователь получен успешно - id: ${user.id}, name: ${user.name}');
      return user;
    } catch (e, stackTrace) {
      developer.log('AuthService: Ошибка при получении пользователя', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<User> getUserById(int id) async {
    developer.log('AuthService: Запрос пользователя по ID: $id');
    return apiClient.get<User>(
      '/user/$id',
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<User> updateUser(String name) async {
    developer.log('AuthService: Обновление имени пользователя на: $name');
    return apiClient.put<User>(
      '/user',
      data: {'name': name},
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<bool> isAuthenticated() async {
    developer.log('AuthService: Проверка авторизации');
    try {
      await getCurrentUser();
      developer.log('AuthService: Пользователь авторизован');
      return true;
    } catch (e) {
      developer.log('AuthService: Пользователь НЕ авторизован', error: e);
      return false;
    }
  }

  @override
  String getLoginUrl() {
    // GitHub OAuth - согласно бекенду
    final url = "${apiClient.baseUrl}/login?provider=github";
    developer.log('AuthService: URL для входа: $url');
    return url;
  }

  @override
  Future<void> logout() async {
    developer.log('AuthService: Выход из системы GET /logout');
    await apiClient.get<Map<String, dynamic>>(
      '/logout',
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }

  Future<User> testLogin({String? username, String? email}) async {
    developer.log('AuthService: Тестовый вход GET /test-login');
    final queryParams = <String, dynamic>{};
    if (username != null) queryParams['username'] = username;
    if (email != null) queryParams['email'] = email;

    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/test-login',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );

      return await getCurrentUser();
    } catch (e) {
      developer.log('AuthService: Ошибка тестового входа', error: e);
      rethrow;
    }
  }
}
