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
  Future<String> getLoginUrl({String? provider}) async {
    developer.log('AuthService: Получение URL для OAuth2 авторизации');
    
    // Определяем URL для редиректа обратно в приложение
    final callbackUrl = Uri.base.origin;
    
    final queryParams = <String, String>{
      'provider': provider ?? 'github',
      'redirect': 'false', // Получаем URL в JSON, а не делаем редирект сразу
      'to': callbackUrl, // Куда редиректить после авторизации
    };

    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/login',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );
      
      final loginUrl = response['url'] as String;
      developer.log('AuthService: Получен URL для входа: $loginUrl (redirect to: ${queryParams['to']})');
      return loginUrl;
    } catch (e, stackTrace) {
      developer.log('AuthService: Ошибка при получении URL для входа', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> testLogin({String? name, String? email}) async {
    developer.log('AuthService: Создание временного пользователя');
    
    final queryParams = <String, String>{};
    if (name != null) queryParams['name'] = name;
    if (email != null) queryParams['email'] = email;
    
    try {
      await apiClient.get<Map<String, dynamic>>(
        '/test-login',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );
      developer.log('AuthService: Временный пользователь создан и cookie установлена');
    } catch (e, stackTrace) {
      developer.log('AuthService: Ошибка при создании временного пользователя', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    developer.log('AuthService: Выход из системы GET /logout');
    try {
      await apiClient.get<Map<String, dynamic>>(
        '/logout',
        fromJson: (data) => data as Map<String, dynamic>,
      );
      developer.log('AuthService: Успешный выход из системы');
    } catch (e, stackTrace) {
      developer.log('AuthService: Ошибка при выходе из системы', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
