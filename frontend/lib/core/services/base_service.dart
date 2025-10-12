import '/core/api/api_client.dart';

/// Абстрактный класс сервиса для работы с API
abstract class BaseService {
  final ApiClient apiClient;

  BaseService({required this.apiClient});
}
