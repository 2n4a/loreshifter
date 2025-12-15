import '/core/api/api_client.dart';
import '/core/services/base_service.dart';
import 'dart:developer' as developer;

/// Сервис для системных операций
class SystemService extends BaseService {
  SystemService({required super.apiClient});

  /// Проверка работоспособности сервиса
  Future<bool> checkLiveness() async {
    developer.log('SystemService: Проверка работоспособности сервиса');
    try {
      await apiClient.get<Map<String, dynamic>>(
        '/liveness',
        fromJson: (data) => data as Map<String, dynamic>,
      );
      developer.log('SystemService: Сервис работает');
      return true;
    } catch (e) {
      developer.log('SystemService: Ошибка проверки работоспособности', error: e);
      return false;
    }
  }
}

