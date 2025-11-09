import '/features/worlds/domain/models/world.dart';

/// Интерфейс для сервиса работы с мирами
abstract class WorldService {
  /// Получить список миров
  Future<List<World>> getWorlds({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    bool? isPublic,
    String? filter,
  });

  /// Получить мир по ID
  Future<World> getWorldById(int id, {bool includeData = false});

  /// Создать новый мир
  Future<World> createWorld({
    required String name,
    required bool isPublic,
    String? description,
    dynamic data,
  });

  /// Обновить информацию о мире
  Future<World> updateWorld({
    required int id,
    String? name,
    bool? isPublic,
    String? description,
    dynamic data,
  });

  /// Удалить мир
  Future<World> deleteWorld(int id);

  /// Создать копию мира
  Future<World> copyWorld(int id);
}
