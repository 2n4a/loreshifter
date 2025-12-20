import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/core/services/world_service.dart';
import '/features/auth/auth_cubit.dart';
import '/features/worlds/worlds_cubit.dart';

class CreateWorldScreen extends StatefulWidget {
  const CreateWorldScreen({super.key});

  @override
  State<CreateWorldScreen> createState() => _CreateWorldScreenState();
}

class _CreateWorldScreenState extends State<CreateWorldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createWorld() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      final world = await worldService.createWorld(
        name: _nameController.text,
        public: _isPublic,
        description:
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
      );

      if (!mounted) return;

      // Refresh the user worlds list
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        context.read<WorldsCubit>().loadUserWorlds(authState.user.id);
      }

  // После создания возвращаемся в домашний экран и показываем вкладку "Мои миры"
  // (Tab index 1 соответствует второй вкладке — "МОИ МИРЫ")
  context.go('/?tab=1');
    } catch (e) {
      setState(() {
        _error = 'Ошибка при создании мира: $e';
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
      appBar: AppBar(title: const Text('Создать мир')),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Center(
              child: Text('Необходимо авторизоваться для создания мира'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Создайте новый мир для ваших историй',
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 32),

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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                  // Кнопка создания мира
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createWorld,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Создать мир'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Кнопка отмены
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Отмена'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
