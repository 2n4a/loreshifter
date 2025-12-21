import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/worlds/domain/models/world.dart';
import '/core/services/world_service.dart';
import '/features/worlds/worlds_cubit.dart';
import '/features/auth/auth_cubit.dart';

class EditWorldScreen extends StatefulWidget {
  final int worldId;
  final int? sourceWorldId;
  final bool isFreshCopy;

  const EditWorldScreen({
    super.key,
    required this.worldId,
    this.sourceWorldId,
    this.isFreshCopy = false,
  });

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
        public: _isPublic,
        description:
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
      );

      if (!mounted) return;

      setState(() {
        _world = updatedWorld;
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Мир успешно обновлен')));

      // Refresh the worlds list to show updated data
      context.read<WorldsCubit>().loadWorlds();
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        context.read<WorldsCubit>().loadUserWorlds(authState.user.id);
      }

      // Navigate back after successful save
      // If we came from a copied world scenario, pop twice and navigate to the new world detail
      if (widget.sourceWorldId != null) {
        context.pop(); // Pop edit screen
        if (mounted) {
          context.pop(); // Pop original world detail screen
        }
        if (mounted) {
          context.push('/worlds/${widget.worldId}'); // Navigate to new world detail
        }
      } else {
        context.pop(); // Just go back normally
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка при обновлении мира: $e';
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

      // Refresh the worlds list to remove the deleted world
      context.read<WorldsCubit>().loadWorlds();
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        context.read<WorldsCubit>().loadUserWorlds(authState.user.id);
      }

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
    return PopScope(
      canPop: !widget.isFreshCopy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Show confirmation dialog for fresh copies
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отменить копирование'),
            content: const Text(
              'Все несохраненные изменения будут отменены. '
              'Копия мира будет удалена. '
              'Продолжить?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );

        if (shouldDiscard == true && context.mounted) {
          // Delete the copied world
          try {
            final worldService = context.read<WorldService>();
            await worldService.deleteWorld(widget.worldId);
            
            if (context.mounted) {
              context.pop();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при удалении мира: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
      },
      child: Scaffold(
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
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadWorld,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
                : _buildWorldForm(),
      ),
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Последнее обновление: ${_formatDate(_world?.lastUpdatedAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 12),

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

            const SizedBox(height: 12),

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

            const SizedBox(height: 12),

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

            const SizedBox(height: 12),

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

            // Кнопка удаления мира (только для владельца)
            if (_world != null && _isOwner())
              Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading || _isDeleting ? null : _showDeleteConfirmation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                      child: const Text('Удалить мир'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _isOwner() {
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated && _world != null) {
      return authState.user.id == _world!.owner.id;
    }
    return false;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Неизвестно';
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
