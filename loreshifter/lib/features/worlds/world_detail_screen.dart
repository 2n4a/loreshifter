import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loreshifter/core/models/world.dart';
import 'package:loreshifter/core/services/world_service.dart';

class WorldDetailScreen extends StatefulWidget {
  final int worldId;

  const WorldDetailScreen({super.key, required this.worldId});

  @override
  State<WorldDetailScreen> createState() => _WorldDetailScreenState();
}

class _WorldDetailScreenState extends State<WorldDetailScreen> {
  bool _isLoading = false;
  World? _world;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorld();
  }

  Future<void> _loadWorld() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      _world = await worldService.getWorldById(widget.worldId);
    } catch (e) {
      setState(() {
        _error = 'Ошибка при загрузке мира: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_world?.name ?? 'Детали мира'),
        actions: [
          if (_world != null && _isOwner())
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/worlds/${widget.worldId}/edit'),
              tooltip: 'Редактировать мир',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _world == null
              ? Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadWorld,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : _buildWorldDetails(),
    );
  }

  bool _isOwner() {
    if (_world == null) return false;
    // В MVP версии мы просто покажем кнопку редактирования для всех,
    // но в реальном приложении нужно проверять ID пользователя
    return true;
  }

  Widget _buildWorldDetails() {
    if (_world == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок мира
          Text(_world!.name, style: Theme.of(context).textTheme.headlineMedium),

          const SizedBox(height: 8),

          // Статус публичности
          Row(
            children: [
              Icon(
                _world!.public ? Icons.public : Icons.lock,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                _world!.public ? 'Публичный мир' : 'Приватный мир',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Описание мира
          Text('Описание', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _world!.description ?? 'Описание отсутствует',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          // Информация о создателе
          Text('Создатель', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(_world!.owner.name.substring(0, 1).toUpperCase()),
            ),
            title: Text(_world!.owner.name),
            onTap: () => context.push('/profile/${_world!.owner.id}'),
          ),

          const SizedBox(height: 16),

          // Дополнительная информация
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Создан', _formatDate(_world!.createdAt)),
                  _buildInfoRow('Обновлен', _formatDate(_world!.lastUpdatedAt)),
                  // Здесь можно добавить больше информации о мире
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Кнопка создания игры
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => context.push('/games/create?worldId=${widget.worldId}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Создать игру'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
