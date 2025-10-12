import '/core/models/user.dart';
import '/core/models/world.dart';
import '/core/services/base_service.dart';
import '/core/services/interfaces/world_service_interface.dart';

/// Заглушка для сервиса работы с мирами
class MockWorldService extends BaseService implements WorldService {
  MockWorldService({required super.apiClient});

  // Фиктивный пользователь-создатель
  final User _mockUser = User(id: 1, name: "Тестовый пользователь");

  // Список фиктивных миров
  final List<World> _mockWorlds = List.generate(10, (index) {
    final createdAt = DateTime.now().subtract(Duration(days: 10 + index));
    final lastUpdatedAt = DateTime.now().subtract(Duration(days: index));

    return World(
      id: index + 1,
      name: "Тестовый мир ${index + 1}",
      public: index % 3 != 0,
      // Некоторые приватные, некоторые публичные
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      owner: User(id: 1, name: "Тестовый пользователь"),
      description:
          index % 2 == 0
              ? "Это описание тестового мира ${index + 1}. Здесь могло бы быть интересное описание фантастического мира."
              : null,
    );
  });

  // Получить список миров
  @override
  Future<List<World>> getWorlds({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    bool? isPublic,
    String? filter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    // Фильтрация и сортировка
    var filteredWorlds = List<World>.from(_mockWorlds);

    // Фильтрация по публичности
    if (isPublic != null) {
      filteredWorlds =
          filteredWorlds.where((world) => world.public == isPublic).toList();
    }

    // Фильтрация по owner_id
    if (filter != null && filter.contains('owner=')) {
      final ownerId = int.tryParse(filter.split('owner=')[1].split(',')[0]);
      if (ownerId != null) {
        filteredWorlds =
            filteredWorlds.where((world) => world.owner.id == ownerId).toList();
      }
    }

    // Сортировка
    if (sort == 'lastUpdatedAt') {
      filteredWorlds.sort(
        (a, b) =>
            order == 'asc'
                ? a.lastUpdatedAt.compareTo(b.lastUpdatedAt)
                : b.lastUpdatedAt.compareTo(a.lastUpdatedAt),
      );
    }

    // Пагинация
    final paginatedWorlds = filteredWorlds.skip(offset).take(limit).toList();

    return paginatedWorlds;
  }

  // Получить мир по ID
  @override
  Future<World> getWorldById(int id, {bool includeData = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final world = _mockWorlds.firstWhere(
      (world) => world.id == id,
      orElse: () => throw Exception('Мир с ID $id не найден'),
    );

    // Если нужны данные, добавляем их
    if (includeData) {
      return World(
        id: world.id,
        name: world.name,
        public: world.public,
        createdAt: world.createdAt,
        lastUpdatedAt: world.lastUpdatedAt,
        owner: world.owner,
        description: world.description,
        data: {
          "lore": "Это тестовые данные для мира ${world.name}",
          "settings": {
            "theme": "fantasy",
            "difficulty": "medium",
            "elements": ["fire", "water", "earth", "air"],
          },
        },
      );
    }

    return world;
  }

  // Создать новый мир
  @override
  Future<World> createWorld({
    required String name,
    required bool isPublic,
    String? description,
    dynamic data,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final newId = _mockWorlds.length + 1;
    final now = DateTime.now();

    final newWorld = World(
      id: newId,
      name: name,
      public: isPublic,
      createdAt: now,
      lastUpdatedAt: now,
      owner: _mockUser,
      description: description,
      data: data,
    );

    // В реальности здесь был бы запрос к API, но мы просто добавим в локальный список
    _mockWorlds.add(newWorld);

    return newWorld;
  }

  // Обновить информацию о мире
  @override
  Future<World> updateWorld({
    required int id,
    String? name,
    bool? isPublic,
    String? description,
    dynamic data,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final index = _mockWorlds.indexWhere((world) => world.id == id);
    if (index == -1) {
      throw Exception('Мир с ID $id не найден');
    }

    final oldWorld = _mockWorlds[index];
    final updatedWorld = World(
      id: id,
      name: name ?? oldWorld.name,
      public: isPublic ?? oldWorld.public,
      createdAt: oldWorld.createdAt,
      lastUpdatedAt: DateTime.now(),
      owner: oldWorld.owner,
      description: description ?? oldWorld.description,
      data: data ?? oldWorld.data,
    );

    _mockWorlds[index] = updatedWorld;

    return updatedWorld;
  }

  // Удалить мир
  @override
  Future<World> deleteWorld(int id) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final index = _mockWorlds.indexWhere((world) => world.id == id);
    if (index == -1) {
      throw Exception('Мир с ID $id не найден');
    }

    final deletedWorld = _mockWorlds[index];
    _mockWorlds.removeAt(index);

    return deletedWorld;
  }

  // Создать копию мира
  @override
  Future<World> copyWorld(int id) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final originalWorld = await getWorldById(id, includeData: true);

    return createWorld(
      name: "${originalWorld.name} (копия)",
      isPublic: originalWorld.public,
      description: originalWorld.description,
      data: originalWorld.data,
    );
  }
}
