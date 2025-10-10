import 'package:loreshifter/core/models/user.dart';
import 'package:loreshifter/core/services/base_service.dart';
import 'package:loreshifter/core/services/interfaces/auth_service_interface.dart';

/// Реальная реализация сервиса аутентификации
class AuthServiceImpl extends BaseService implements AuthService {
  AuthServiceImpl({required super.apiClient});

  @override
  Future<User> getCurrentUser() async {
    return apiClient.get<User>(
      '/user/me',
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<User> getUserById(int id) async {
    return apiClient.get<User>(
      '/user/$id',
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<User> updateUser(String name) async {
    return apiClient.put<User>(
      '/user',
      data: {'name': name},
      fromJson: (data) => User.fromJson(data),
    );
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      await getCurrentUser();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String getLoginUrl() {
    return "${apiClient.baseUrl}/login";
  }
}
