import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/worlds/worlds_cubit.dart';
import '/features/games/games_cubit.dart';

import '../../core/models/world.dart';

class CreateGameScreen extends StatefulWidget {
  final int? worldId;

  const CreateGameScreen({super.key, this.worldId});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  World? _selectedWorld;
  bool _isPublic = true;
  int _maxPlayers = 4;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorlds();
  }

  Future<void> _loadWorlds() async {
    final worldsCubit = context.read<WorldsCubit>();
    await worldsCubit.loadWorlds();

    // Если worldId был предоставлен, выберем этот мир по умолчанию
    if (widget.worldId != null && worldsCubit.state is WorldsLoaded) {
      final worlds = (worldsCubit.state as WorldsLoaded).worlds;
      if (worlds.isNotEmpty) {
        _selectedWorld = worlds.firstWhere(
          (world) => world.id == widget.worldId,
          orElse: () => worlds.first,
        );
      }
    }
  }

  Future<void> _createGame() async {
    if (!_formKey.currentState!.validate() || _selectedWorld == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните все поля')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final gamesCubit = context.read<GamesCubit>();

      final game = await gamesCubit.createGame(
        worldId: _selectedWorld!.id,
        name:
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Игра в мире ${_selectedWorld!.name}',
        isPublic: _isPublic,
        maxPlayers: _maxPlayers,
      );

      if (!mounted) return;

      context.go('/games/${game.id}');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при создании игры: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать игру')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Поле для выбора мира
              BlocBuilder<WorldsCubit, WorldsState>(
                builder: (context, state) {
                  if (state is WorldsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<World> worlds = [];
                  if (state is WorldsLoaded) {
                    worlds = state.worlds;
                  }

                  if (worlds.isEmpty) {
                    return const Text('Нет доступных миров для создания игры');
                  }

                  return DropdownButtonFormField<World>(
                    decoration: const InputDecoration(
                      labelText: 'Выберите мир',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedWorld,
                    items:
                        worlds
                            .map(
                              (world) => DropdownMenuItem<World>(
                                value: world,
                                child: Text(world.name),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWorld = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Пожалуйста, выберите мир';
                      }
                      return null;
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // Поле для ввода названия игры
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название игры (необязательно)',
                  border: OutlineInputBorder(),
                  hintText: 'Оставьте пустым для автоматического названия',
                ),
              ),

              const SizedBox(height: 16),

              // Настройки публичности
              SwitchListTile(
                title: const Text('Публичная игра'),
                subtitle: const Text('Если включено, игра будет видна всем'),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Настройки максимального количества игроков
              Row(
                children: [
                  const Text('Максимальное количество игроков:'),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _maxPlayers,
                    items:
                        [1, 2, 3, 4, 5, 6, 8, 10]
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _maxPlayers = value;
                        });
                      }
                    },
                  ),
                ],
              ),

              const Spacer(),

              // Кнопка создания игры
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGame,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Создать игру'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
