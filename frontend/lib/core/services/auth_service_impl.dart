import '/features/auth/domain/models/user.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/auth_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса аутентификации
class AuthServiceImpl extends BaseService implements AuthService {
  AuthServiceImpl({required super.apiClient});

  @override
  Future<User> getCurrentUser() async {
    developer.log('[SERVICE:AUTH] getCurrentUser() -> GET /user/me');
    try {
      final user = await apiClient.get<User>(
        '/user/me',
        fromJson: (data) => User.fromJson(data),
      );
      developer.log('[SERVICE:AUTH] getCurrentUser() -> Success: User(id=${user.id}, name=${user.name})');
      return user;
    } catch (e, stackTrace) {
      developer.log('[SERVICE:AUTH] getCurrentUser() -> Error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<User> getUserById(int id) async {
    developer.log('[SERVICE:AUTH] getUserById($id) -> GET /user/$id');
    return apiClient.get<User>(
      '/user/$id',
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<User> updateUser(String name) async {
    developer.log('[SERVICE:AUTH] updateUser(name=$name) -> PUT /user');
    return apiClient.put<User>(
      '/user',
      data: {'name': name},
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<bool> isAuthenticated() async {
    developer.log('[SERVICE:AUTH] isAuthenticated() -> checking');
    try {
      await getCurrentUser();
      developer.log('[SERVICE:AUTH] isAuthenticated() -> true');
      return true;
    } catch (e) {
      developer.log('[SERVICE:AUTH] isAuthenticated() -> false');
      return false;
    }
  }

  @override
  Future<String> getLoginUrl({String? provider}) async {
    final providerName = provider ?? 'github';
    final callbackUrl = Uri.base.origin;
    
    developer.log('[SERVICE:AUTH] getLoginUrl(provider=$providerName) -> GET /login');
    
    final queryParams = <String, String>{
      'provider': providerName,
      'redirect': 'false',
      'to': callbackUrl,
    };

    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/login',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );
      
      final loginUrl = response['url'] as String;
      developer.log('[SERVICE:AUTH] getLoginUrl() -> Success: $loginUrl');
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
