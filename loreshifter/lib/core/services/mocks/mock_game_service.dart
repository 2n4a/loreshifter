import 'package:loreshifter/core/models/game.dart';
import 'package:loreshifter/core/models/player.dart';
import 'package:loreshifter/core/models/user.dart';
import 'package:loreshifter/core/models/world.dart';
import 'package:loreshifter/core/services/base_service.dart';
import 'package:loreshifter/core/services/interfaces/game_service_interface.dart';

/// Заглушка для сервиса работы с играми
class MockGameService extends BaseService implements GameService {
  MockGameService({required super.apiClient});

  // Список фиктивных миров для игр
  final List<World> _mockWorlds = List.generate(
    5,
    (index) => World(
      id: index + 1,
      name: "Мир игры ${index + 1}",
      public: true,
      createdAt: DateTime.now().subtract(Duration(days: 10 + index)),
      lastUpdatedAt: DateTime.now().subtract(Duration(days: index)),
      owner: User(id: index % 3 + 1, name: "Автор мира ${index % 3 + 1}"),
      description: "Описание мира для игры ${index + 1}",
    ),
  );

  // Список фиктивных игр
  final List<Game> _mockGames = List.generate(8, (index) {
    final worldIndex = index % 5;
    final isFinished = index >= 6;
    final isPlaying = index >= 3 && index < 6;
    final isWaiting = index < 3;

    final players = List.generate(
      1 + (index % 4),
      (playerIndex) => Player(
        user: User(id: playerIndex + 1, name: "Игрок ${playerIndex + 1}"),
        isReady: isPlaying || isFinished,
        isHost: playerIndex == 0,
        isSpectator: playerIndex == (index % 4),
      ),
    );

    return Game(
      id: index + 1,
      code: "GAME${(index + 1).toString().padLeft(3, '0')}",
      public: index % 2 == 0,
      name: "Тестовая игра ${index + 1}",
      world: World(
        id: worldIndex + 1,
        name: "Мир игры ${worldIndex + 1}",
        public: true,
        createdAt: DateTime.now().subtract(Duration(days: 10 + worldIndex)),
        lastUpdatedAt: DateTime.now().subtract(Duration(days: worldIndex)),
        owner: User(
          id: worldIndex % 3 + 1,
          name: "Автор мира ${worldIndex % 3 + 1}",
        ),
        description: "Описание мира для игры ${worldIndex + 1}",
      ),
      hostId: 1,
      players: players,
      createdAt: DateTime.now().subtract(Duration(days: index)),
      maxPlayers: 4 + (index % 3),
      status:
          isFinished
              ? GameStatus.finished
              : isPlaying
              ? GameStatus.playing
              : GameStatus.waiting,
    );
  });

  // Текущая игра пользователя (null, если пользователь не в игре)
  Game? _currentGame;

  // Получить список игр
  Future<List<Game>> getGames({
    int limit = 25,
    int offset = 0,
    String? sort,
    String? order,
    String? filter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    var filteredGames = List<Game>.from(_mockGames);

    // Фильтрация
    if (filter != null) {
      if (filter.contains('status=')) {
        final status = filter.split('status=')[1].split(',')[0];
        filteredGames =
            filteredGames
                .where(
                  (game) => game.status.toString().split('.').last == status,
                )
                .toList();
      }

      if (filter.contains('world=')) {
        final worldId = int.tryParse(filter.split('world=')[1].split(',')[0]);
        if (worldId != null) {
          filteredGames =
              filteredGames.where((game) => game.world.id == worldId).toList();
        }
      }

      if (filter.contains('host=')) {
        final hostId = int.tryParse(filter.split('host=')[1].split(',')[0]);
        if (hostId != null) {
          filteredGames =
              filteredGames.where((game) => game.hostId == hostId).toList();
        }
      }
    }

    // Сортировка
    if (sort == 'createdAt') {
      filteredGames.sort(
        (a, b) =>
            order == 'asc'
                ? a.createdAt.compareTo(b.createdAt)
                : b.createdAt.compareTo(a.createdAt),
      );
    }

    // Пагинация
    final paginatedGames = filteredGames.skip(offset).take(limit).toList();

    return paginatedGames;
  }

  // Получить информацию о игре по ID
  Future<Game> getGameById(int id) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (id == 0 && _currentGame != null) {
      return _currentGame!;
    }

    final game = _mockGames.firstWhere(
      (game) => game.id == id,
      orElse: () => throw Exception('Игра с ID $id не найдена'),
    );

    return game;
  }

  // Получить текущую игру
  @override
  Future<Game> getCurrentGame() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentGame == null) {
      throw Exception('Вы не находитесь в игре');
    }

    return _currentGame!;
  }

  // Получить игру по коду
  Future<Game> getGameByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final game = _mockGames.firstWhere(
      (game) => game.code.toLowerCase() == code.toLowerCase(),
      orElse: () => throw Exception('Игра с кодом $code не найдена'),
    );

    return game;
  }

  // Создать новую игру
  Future<Game> createGame({
    required int worldId,
    required bool isPublic,
    String? name,
    int? maxPlayers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    // Находим мир по ID
    final worldIndex = _mockWorlds.indexWhere((world) => world.id == worldId);
    final world =
        worldIndex != -1
            ? _mockWorlds[worldIndex]
            : World(
              id: worldId,
              name: "Мир игры $worldId",
              public: true,
              createdAt: DateTime.now().subtract(const Duration(days: 10)),
              lastUpdatedAt: DateTime.now(),
              owner: User(id: 1, name: "Автор мира"),
              description: "Описание мира для игры",
            );

    // Генерируем случайный код для игры
    final gameId = _mockGames.length + 1;
    final gameCode = "GAME${gameId.toString().padLeft(3, '0')}";

    // Создаем игру
    final newGame = Game(
      id: gameId,
      code: gameCode,
      public: isPublic,
      name: name ?? "Игра в мире ${world.name}",
      world: world,
      hostId: 1,
      // Текущий пользователь всегда хост
      players: [
        Player(
          user: User(id: 1, name: "Тестовый пользователь"),
          isReady: false,
          isHost: true,
          isSpectator: false,
        ),
      ],
      createdAt: DateTime.now(),
      maxPlayers: maxPlayers ?? 4,
      status: GameStatus.waiting,
    );

    // Добавляем игру в список
    _mockGames.add(newGame);

    // Устанавливаем текущую игру
    _currentGame = newGame;

    return newGame;
  }

  // Обновить информацию об игре
  Future<Game> updateGame({
    required int id,
    bool? isPublic,
    String? name,
    int? hostId,
    int? maxPlayers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final index = _mockGames.indexWhere((game) => game.id == id);
    if (index == -1) {
      throw Exception('Игра с ID $id не найдена');
    }

    final oldGame = _mockGames[index];

    // Проверяем, что игра еще в статусе ожидания
    if (oldGame.status != GameStatus.waiting) {
      throw Exception(
        'Нельзя изменить игру, которая уже началась или завершилась',
      );
    }

    // Проверяем, что новый хост существует среди игроков
    if (hostId != null) {
      final hostExists = oldGame.players.any(
        (player) => player.user.id == hostId,
      );
      if (!hostExists) {
        throw Exception('Игрок с ID $hostId не найден среди участников игры');
      }
    }

    // Проверяем, что maxPlayers не меньше текущего числа игроков
    if (maxPlayers != null && maxPlayers < oldGame.players.length) {
      throw Exception(
        'Максимальное количество игроков не может быть меньше текущего',
      );
    }

    // Обновляем игру
    final updatedPlayers = List<Player>.from(oldGame.players);
    if (hostId != null) {
      updatedPlayers.replaceRange(
        0,
        updatedPlayers.length,
        updatedPlayers
            .map(
              (player) => Player(
                user: player.user,
                isReady: player.isReady,
                isHost: player.user.id == hostId,
                isSpectator: player.isSpectator,
              ),
            )
            .toList(),
      );
    }

    final updatedGame = Game(
      id: oldGame.id,
      code: oldGame.code,
      public: isPublic ?? oldGame.public,
      name: name ?? oldGame.name,
      world: oldGame.world,
      hostId: hostId ?? oldGame.hostId,
      players: updatedPlayers,
      createdAt: oldGame.createdAt,
      maxPlayers: maxPlayers ?? oldGame.maxPlayers,
      status: oldGame.status,
    );

    // Обновляем игру в списке
    _mockGames[index] = updatedGame;

    // Обновляем текущую игру, если это она
    if (_currentGame?.id == id) {
      _currentGame = updatedGame;
    }

    return updatedGame;
  }

  // Присоединиться к игре по ID
  Future<Game> joinGameById(int id, {bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Проверяем, находится ли пользователь уже в игре
    if (_currentGame != null && _currentGame!.id != id && !force) {
      throw Exception(
        'Вы уже находитесь в игре. Выйдите или используйте force=true.',
      );
    }

    // Находим игру
    final gameIndex = _mockGames.indexWhere((game) => game.id == id);
    if (gameIndex == -1) {
      throw Exception('Игра с ID $id не найдена');
    }

    final game = _mockGames[gameIndex];

    // Проверяем, не превышен ли лимит игроков
    if (game.players.length >= game.maxPlayers) {
      throw Exception('Игра уже заполнена');
    }

    // Проверяем, не присоединился ли пользователь уже
    final isAlreadyJoined = game.players.any((player) => player.user.id == 1);
    if (isAlreadyJoined && !force) {
      throw Exception('Вы уже присоединились к этой игре');
    }

    // Создаем обновленный список игроков
    List<Player> updatedPlayers;
    if (isAlreadyJoined) {
      updatedPlayers = game.players;
    } else {
      updatedPlayers = List<Player>.from(game.players);
      updatedPlayers.add(
        Player(
          user: User(id: 1, name: "Тестовый пользователь"),
          isReady: false,
          isHost: false,
          isSpectator: false,
        ),
      );
    }

    // Создаем обновленную игру
    final updatedGame = Game(
      id: game.id,
      code: game.code,
      public: game.public,
      name: game.name,
      world: game.world,
      hostId: game.hostId,
      players: updatedPlayers,
      createdAt: game.createdAt,
      maxPlayers: game.maxPlayers,
      status: game.status,
    );

    // Обновляем игру в списке
    _mockGames[gameIndex] = updatedGame;

    // Устанавливаем текущую игру
    _currentGame = updatedGame;

    return updatedGame;
  }

  // Присоединиться к игре по коду
  Future<Game> joinGameByCode(String code, {bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Находим игру
    final gameIndex = _mockGames.indexWhere(
      (game) => game.code.toLowerCase() == code.toLowerCase(),
    );

    if (gameIndex == -1) {
      throw Exception('Игра с кодом $code не найдена');
    }

    final game = _mockGames[gameIndex];

    // Присоединяемся к игре
    return joinGameById(game.id, force: force);
  }

  // Покинуть текущую игру
  Future<void> leaveGame() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentGame == null) {
      throw Exception('Вы не находитесь в игре');
    }

    final gameIndex = _mockGames.indexWhere(
      (game) => game.id == _currentGame!.id,
    );
    if (gameIndex != -1) {
      final game = _mockGames[gameIndex];

      // Удаляем пользователя из списка игроков
      final updatedPlayers =
          game.players.where((player) => player.user.id != 1).toList();

      // Если игрок был хостом, передаем права хоста следующему игроку
      int newHostId = game.hostId;
      if (game.hostId == 1 && updatedPlayers.isNotEmpty) {
        newHostId = updatedPlayers[0].user.id;

        updatedPlayers.replaceRange(
          0,
          updatedPlayers.length,
          updatedPlayers
              .map(
                (player) => Player(
                  user: player.user,
                  isReady: player.isReady,
                  isHost: player.user.id == newHostId,
                  isSpectator: player.isSpectator,
                ),
              )
              .toList(),
        );
      }

      // Обновляем игру
      final updatedGame = Game(
        id: game.id,
        code: game.code,
        public: game.public,
        name: game.name,
        world: game.world,
        hostId: newHostId,
        players: updatedPlayers,
        createdAt: game.createdAt,
        maxPlayers: game.maxPlayers,
        status: game.status,
      );

      _mockGames[gameIndex] = updatedGame;
    }

    // Сбрасываем текущую игру
    _currentGame = null;
  }
}
