import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '/features/worlds/domain/models/world.dart';
import '/features/auth/auth_cubit.dart';
import '/core/services/world_service.dart';
import '/core/widgets/modern_card.dart';
import '/core/widgets/neon_button.dart';
import '/core/widgets/user_avatar.dart';
import '/core/widgets/info_components.dart';

class WorldDetailScreen extends StatefulWidget {
  final int worldId;

  const WorldDetailScreen({super.key, required this.worldId});

  @override
  State<WorldDetailScreen> createState() => _WorldDetailScreenState();
}

class _WorldDetailScreenState extends State<WorldDetailScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  World? _world;
  String? _error;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadWorld();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload world data when returning from edit screen
    if (ModalRoute.of(context)?.isCurrent == true && _world != null) {
      _loadWorld();
    }
  }

  Future<void> _loadWorld() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      _world = await worldService.getWorldById(widget.worldId);
      if (!mounted) return;
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _slideController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка при загрузке мира: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyWorld() async {
    // Check authentication
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Необходимо авторизоваться для копирования мира')),
      );
      return;
    }

    try {
      final worldService = context.read<WorldService>();
      final copiedWorld = await worldService.copyWorld(widget.worldId);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Мир "${copiedWorld.name}" успешно скопирован')),
      );
      
      // Navigate to the edit screen of the copied world with fresh copy flag
      context.push('/worlds/${copiedWorld.id}/edit?sourceWorldId=${widget.worldId}&isFreshCopy=true');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при копировании мира: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(cs),
          if (_isLoading)
            _buildLoadingSliver(cs)
          else if (_error != null && _world == null)
            _buildErrorSliver(cs)
          else
            _buildContentSliver(),
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.pop(),
        tooltip: 'Назад',
      ),
      title: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Text(
              _world?.name ?? 'Мир',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      actions: [
        if (_world != null && _isOwner())
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => context.push('/worlds/${widget.worldId}/edit'),
            tooltip: 'Редактировать мир',
          ),
      ],
    );
  }

  Widget _buildLoadingSliver(ColorScheme cs) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 12),
            Text(
              'Загрузка мира...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSliver(ColorScheme cs) {
    return SliverFillRemaining(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          child: ModernCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(
                  'Упс! Что-то пошло не так',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Неизвестная ошибка',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                NeonButton(
                  text: 'Повторить попытку',
                  icon: Icons.refresh,
                  onPressed: _loadWorld,
                  color: cs.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    final items = <Widget>[
      const SizedBox(height: 12),
      _buildHeaderSection(),
      const SizedBox(height: 12),
      _buildDescriptionSection(),
      const SizedBox(height: 12),
      _buildOwnerSection(),
      const SizedBox(height: 12),
      _buildInfoSection(),
      const SizedBox(height: 12),
      _buildActionButtons(),
      const SizedBox(height: 12),
    ];

    Widget wrapAnimated(Widget child) => FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: child),
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => wrapAnimated(items[index]),
        childCount: items.length,
      ),
    );
  }

  Widget _buildHeaderSection() {
    if (_world == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _world!.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge(
            text: _world!.public ? 'Публичный мир' : 'Приватный мир',
            color: _world!.public ? cs.primary : cs.secondary,
            icon: _world!.public ? Icons.public : Icons.lock,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    if (_world == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Описание',
            icon: Icons.description_outlined,
            iconColor: cs.primary,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Text(
            _world!.description ?? 'Описание отсутствует',
            style: theme.textTheme.bodyLarge?.copyWith(
              color:
                  _world!.description != null
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection() {
    if (_world == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ModernCard(
      onTap: () => context.push('/profile/${_world!.owner.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Создатель',
            icon: Icons.person_outline,
            iconColor: cs.primary,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatar(
                name: _world!.owner.name,
                size: 56,
                withGlow: true,
                glowColor: cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _world!.owner.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Нажмите, чтобы посмотреть профиль',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    if (_world == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Информация',
            icon: Icons.info_outline,
            iconColor: cs.secondary,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          InfoTile(
            label: 'Создан',
            value: _formatDate(_world!.createdAt),
            icon: Icons.calendar_today_outlined,
            iconColor: cs.secondary,
          ),
          InfoTile(
            label: 'Обновлен',
            value: _formatDate(_world!.lastUpdatedAt),
            icon: Icons.update_outlined,
            iconColor: cs.primary,
            withDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        NeonButton(
          text: 'Создать игру',
          icon: Icons.add_circle_outline,
          onPressed:
              () => context.push('/games/create?worldId=${widget.worldId}'),
          size: ButtonSize.large,
          style: NeonButtonStyle.gradient, // мягкий градиент по умолчанию
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'Копировать мир',
                icon: Icons.copy_outlined,
                onPressed: _copyWorld,
                style: NeonButtonStyle.outlined,
                color: cs.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'История мира',
                icon: Icons.history,
                onPressed: () => context.push('/worlds/${widget.worldId}/history'),
                style: NeonButtonStyle.outlined,
                color: cs.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'Поделиться',
                icon: Icons.share_outlined,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Функция в разработке')),
                  );
                },
                style: NeonButtonStyle.outlined,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'Избранное',
                icon: Icons.favorite_outline,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Добавлено в избранное')),
                  );
                },
                style: NeonButtonStyle.outlined,
                color: cs.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isOwner() {
    if (_world == null) return false;
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return false;
    return _world!.owner.id == authState.user.id;
  }

  String _formatDate(DateTime date) {
    final months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'юл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
