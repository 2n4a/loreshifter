import '/features/worlds/domain/models/world.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/world_service_interface.dart';
import 'dart:developer' as developer;

/// Реальная реализация сервиса работы с мирами
class WorldServiceImpl extends BaseService implements WorldService {
  WorldServiceImpl({required super.apiClient});

  @override
  Future<List<World>> getWorlds({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    bool? isPublic,
    String? filter,
  }) async {
    developer.log('WorldService: Запрос списка миров');
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (sort != null) 'sort': sort,
      if (order != null) 'order': order,
      if (isPublic != null) 'public': isPublic ? 1 : 0,
      if (filter != null) 'filter': filter,
    };

    return apiClient.get<List<World>>(
      '/world',
      queryParameters: queryParams,
      fromJson: (data) => (data as List)
          .map((e) => World.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<World> getWorldById(int id, {bool includeData = false}) async {
    developer.log('WorldService: Запрос мира по ID: $id (includeData: $includeData)');
    final queryParams = <String, dynamic>{
      if (includeData) 'include': 'data',
    };

    return apiClient.get<World>(
      '/world/$id',
      queryParameters: queryParams,
      fromJson: (data) => World.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<World> createWorld({
    required String name,
    required bool isPublic,
    String? description,
    dynamic data,
  }) async {
    developer.log('WorldService: Создание мира');
    return apiClient.post<World>(
      '/world',
      data: {
        'name': name,
        'public': isPublic,
        if (description != null) 'description': description,
        if (data != null) 'data': data,
      },
      fromJson: (data) => World.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<World> updateWorld({
    required int id,
    String? name,
    bool? isPublic,
    String? description,
    dynamic data,
  }) async {
    developer.log('WorldService: Обновление мира $id');
    return apiClient.put<World>(
      '/world/$id',
      data: {
        if (name != null) 'name': name,
        if (isPublic != null) 'public': isPublic,
        if (description != null) 'description': description,
        if (data != null) 'data': data,
      },
      fromJson: (data) => World.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<World> deleteWorld(int id) async {
    developer.log('WorldService: Удаление мира $id');
    return apiClient.delete<World>(
      '/world/$id',
      fromJson: (data) => World.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<World> copyWorld(int id) async {
    developer.log('WorldService: Копирование мира $id');
    return apiClient.post<World>(
      '/world/$id/copy',
      fromJson: (data) => World.fromJson(data as Map<String, dynamic>),
    );
  }
}

