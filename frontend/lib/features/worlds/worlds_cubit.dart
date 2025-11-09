import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/features/worlds/domain/models/world.dart';
import '/core/services/world_service.dart';

// Состояния для работы с мирами
abstract class WorldsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WorldsInitial extends WorldsState {}

class WorldsLoading extends WorldsState {}

class WorldsLoaded extends WorldsState {
  final List<World> worlds;

  WorldsLoaded(this.worlds);

  @override
  List<Object?> get props => [worlds];
}

class UserWorldsLoaded extends WorldsState {
  final List<World> worlds;

  UserWorldsLoaded(this.worlds);

  @override
  List<Object?> get props => [worlds];
}

class PopularWorldsLoaded extends WorldsState {
  final List<World> worlds;

  PopularWorldsLoaded(this.worlds);

  @override
  List<Object?> get props => [worlds];
}

class WorldsFailure extends WorldsState {
  final String message;

  WorldsFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// Кубит для работы с мирами
class WorldsCubit extends Cubit<WorldsState> {
  final WorldService _worldService;

  WorldsCubit({required WorldService worldService})
    : _worldService = worldService,
      super(WorldsInitial());

  // Загрузить список всех доступных миров
  Future<void> loadWorlds() async {
    emit(WorldsLoading());
    try {
      final worlds = await _worldService.getWorlds();
      emit(WorldsLoaded(worlds));
    } catch (e) {
      emit(WorldsFailure(e.toString()));
    }
  }

  // Загрузить миры пользователя
  Future<void> loadUserWorlds(int userId) async {
    emit(WorldsLoading());
    try {
      final worlds = await _worldService.getWorlds(filter: 'owner=$userId');
      emit(UserWorldsLoaded(worlds));
    } catch (e) {
      emit(WorldsFailure(e.toString()));
    }
  }

  // Загрузить популярные миры
  Future<void> loadPopularWorlds() async {
    emit(WorldsLoading());
    try {
      final worlds = await _worldService.getWorlds(
        isPublic: true,
        sort: 'lastUpdatedAt',
        order: 'desc',
        limit: 10,
      );
      emit(PopularWorldsLoaded(worlds));
    } catch (e) {
      emit(WorldsFailure(e.toString()));
    }
  }
}
