import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/core/models/world.dart';
import '/core/services/world_service.dart';

class EditWorldScreen extends StatefulWidget {
  final int worldId;

  const EditWorldScreen({super.key, required this.worldId});

  @override
  State<EditWorldScreen> createState() => _EditWorldScreenState();
}

class _EditWorldScreenState extends State<EditWorldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = true;
  bool _isLoading = false;
  bool _isDeleting = false;
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
      _world = await worldService.getWorldById(
        widget.worldId,
        includeData: true,
      );

      _nameController.text = _world!.name;
      _descriptionController.text = _world!.description ?? '';
      _isPublic = _world!.public;
    } catch (e) {
      _error = 'Ошибка при загрузке мира: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveWorld() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      final updatedWorld = await worldService.updateWorld(
        id: widget.worldId,
        name: _nameController.text,
        isPublic: _isPublic,
        description:
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
      );

      if (!mounted) return;

      setState(() {
        _world = updatedWorld;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Мир успешно обновлен')));
    } catch (e) {
      setState(() {
        _error = 'Ошибка при обновлении мира: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteWorld() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      await worldService.deleteWorld(widget.worldId);

      if (!mounted) return;

      context.go('/');
    } catch (e) {
      setState(() {
        _error = 'Ошибка при удалении мира: $e';
        _isDeleting = false;
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить мир'),
            content: const Text(
              'Вы уверены, что хотите удалить этот мир? '
              'Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteWorld();
                },
                child: Text(
                  'Удалить',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_world?.name ?? 'Редактирование мира'),
        actions: [
          if (_world != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _showDeleteConfirmation,
              tooltip: 'Удалить мир',
            ),
        ],
      ),
      body:
          _isLoading && _world == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _world == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadWorld,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
              : _buildWorldForm(),
    );
  }

  Widget _buildWorldForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация о мире
            Text(
              'Создано: ${_formatDate(_world?.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Последнее обновление: ${_formatDate(_world?.lastUpdatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 24),

            // Поле для названия мира
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название мира',
                border: OutlineInputBorder(),
                hintText: 'Введите название мира',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, введите название мира';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Поле для описания мира
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание мира',
                border: OutlineInputBorder(),
                hintText: 'Опишите ваш мир...',
              ),
              maxLines: 5,
            ),

            const SizedBox(height: 16),

            // Переключатель для публичности мира
            SwitchListTile(
              title: const Text('Публичный мир'),
              subtitle: const Text(
                'Если включено, мир будет доступен всем пользователям',
              ),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
            ),

            const SizedBox(height: 32),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            // Кнопка сохранения изменений
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || _isDeleting ? null : _saveWorld,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Сохранить изменения'),
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка создания игры на основе этого мира
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    _isLoading || _isDeleting
                        ? null
                        : () => context.push(
                          '/games/create?worldId=${widget.worldId}',
                        ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Создать игру на основе этого мира'),
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка отмены
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed:
                    _isLoading || _isDeleting ? null : () => context.go('/'),
                child: const Text('Назад'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Неизвестно';
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
