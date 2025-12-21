import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/auth/auth_cubit.dart';
import '/features/auth/domain/models/user.dart';
import '/core/services/interfaces/auth_service_interface.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  User? _user;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();

      if (widget.userId == null) {
        // Загружаем текущего пользователя
        final authState = context.read<AuthCubit>().state;
        if (authState is Authenticated) {
          _user = authState.user;
        } else {
          // Пытаемся получить текущего пользователя через API
          try {
            _user = await authService.getCurrentUser();
          } catch (e) {
            _error = 'Не удалось загрузить данные пользователя';
          }
        }
      } else {
        // Загружаем профиль другого пользователя по ID
        try {
          _user = await authService.getUserById(widget.userId!);
        } catch (e) {
          _error = 'Не удалось загрузить данные пользователя';
        }
      }

      if (_user != null) {
        _nameController.text = _user!.name;
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Имя не может быть пустым';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthCubit>().updateUserName(_nameController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль успешно обновлен')));
    } catch (e) {
      setState(() {
        _error = 'Не удалось обновить профиль: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    context.read<AuthCubit>().logout();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = widget.userId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'Мой профиль' : 'Профиль пользователя'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _logout,
              tooltip: 'Выйти',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _user == null
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
                      onPressed: _loadUserData,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
              : _buildProfileContent(isCurrentUser),
    );
  }

  Widget _buildProfileContent(bool isCurrentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар пользователя
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _user?.name.substring(0, 1).toUpperCase() ?? '?',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Форма с данными пользователя
          if (isCurrentUser)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя пользователя',
                border: OutlineInputBorder(),
              ),
            )
          else
            Card(
              child: ListTile(
                title: const Text('Имя'),
                subtitle: Text(_user?.name ?? ''),
              ),
            ),

          if (_user?.email != null && isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: ListTile(
                  title: const Text('Email'),
                  subtitle: Text(_user!.email!),
                ),
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Кнопка сохранения изменений
          if (isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Сохранить изменения'),
              ),
            ),
        ],
      ),
    );
  }
}
