import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loreshifter/core/models/world.dart';
import 'package:loreshifter/core/services/world_service.dart';
import 'package:loreshifter/core/theme/app_theme.dart';
import 'package:loreshifter/core/widgets/modern_card.dart';
import 'package:loreshifter/core/widgets/neon_button.dart';
import 'package:loreshifter/core/widgets/user_avatar.dart';
import 'package:loreshifter/core/widgets/info_components.dart';

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
      duration: AppTheme.slowAnimation,
      vsync: this,
    );

    _slideController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: AppTheme.defaultCurve),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: AppTheme.defaultCurve),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadWorld() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final worldService = context.read<WorldService>();
      _world = await worldService.getWorldById(widget.worldId);

      // Запускаем анимации после загрузки
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      _slideController.forward();
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
      backgroundColor: AppTheme.darkBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            _buildLoadingSliver()
          else if (_error != null && _world == null)
            _buildErrorSliver()
          else
            _buildContentSliver(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.pop(),
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.surfaceContainer,
          foregroundColor: Colors.white,
        ),
      ),
      actions: [
        if (_world != null && _isOwner())
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => context.push('/worlds/${widget.worldId}/edit'),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.neonBlue.withAlpha(25),
                foregroundColor: AppTheme.neonBlue,
              ),
              tooltip: 'Редактировать мир',
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16, right: 60),
        title: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Text(
                _world?.name ?? 'Детали мира',
                style: AppTheme.neonTextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  intensity: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.darkBackground,
                AppTheme.darkBackground.withAlpha(200),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.neonShadow(
                  AppTheme.neonBlue,
                  intensity: 0.3,
                ),
              ),
              child: CircularProgressIndicator(
                color: AppTheme.neonBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Загрузка мира...',
              style: AppTheme.neonTextStyle(
                color: AppTheme.neonBlue,
                fontSize: 16,
                intensity: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          child: ModernCard(
            color: AppTheme.surfaceContainer,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.neonPink),
                const SizedBox(height: 16),
                Text(
                  'Упс! Что-то пошло не так',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                NeonButton(
                  text: 'Повторить попытку',
                  icon: Icons.refresh,
                  onPressed: _loadWorld,
                  color: AppTheme.neonBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 16),
              _buildDescriptionSection(),
              const SizedBox(height: 16),
              _buildOwnerSection(),
              const SizedBox(height: 16),
              _buildInfoSection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    if (_world == null) return const SizedBox.shrink();

    return ModernCard(
      gradient: AppTheme.subtleGradient,
      withGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _world!.name,
                  style: AppTheme.neonTextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    intensity: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge(
            text: _world!.public ? 'Публичный мир' : 'Приватный мир',
            color: _world!.public ? AppTheme.neonGreen : AppTheme.neonOrange,
            icon: _world!.public ? Icons.public : Icons.lock,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    if (_world == null) return const SizedBox.shrink();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Описание',
            icon: Icons.description_outlined,
            iconColor: AppTheme.neonPurple,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            _world!.description ?? 'Описание отсутствует',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color:
                  _world!.description != null ? Colors.white : Colors.white54,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection() {
    if (_world == null) return const SizedBox.shrink();

    return ModernCard(
      onTap: () => context.push('/profile/${_world!.owner.id}'),
      withAnimation: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Создатель',
            icon: Icons.person_outline,
            iconColor: AppTheme.neonBlue,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatar(
                name: _world!.owner.name,
                size: 56,
                withGlow: true,
                glowColor: AppTheme.neonBlue,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _world!.owner.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите, чтобы посмотреть профиль',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.neonBlue),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.neonBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    if (_world == null) return const SizedBox.shrink();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Информация',
            icon: Icons.info_outline,
            iconColor: AppTheme.neonGreen,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          InfoTile(
            label: 'Создан',
            value: _formatDate(_world!.createdAt),
            icon: Icons.calendar_today_outlined,
            iconColor: AppTheme.neonGreen,
          ),
          InfoTile(
            label: 'Обновлен',
            value: _formatDate(_world!.lastUpdatedAt),
            icon: Icons.update_outlined,
            iconColor: AppTheme.neonBlue,
            withDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          NeonButton(
            text: 'Создать игру',
            icon: Icons.add_circle_outline,
            onPressed:
                () => context.push('/games/create?worldId=${widget.worldId}'),
            size: ButtonSize.large,
            style: NeonButtonStyle.gradient,
          ),
          const SizedBox(height: 12),
          NeonButton(
            text: 'История мира',
            icon: Icons.history,
            onPressed: () => context.push('/worlds/${widget.worldId}/history'),
            style: NeonButtonStyle.outlined,
            color: AppTheme.neonGreen,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'Поделиться',
                  icon: Icons.share_outlined,
                  onPressed: () {
                    // Логика для шаринга
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Функция в разработке'),
                        backgroundColor: AppTheme.surfaceContainerHigh,
                      ),
                    );
                  },
                  style: NeonButtonStyle.outlined,
                  color: AppTheme.neonBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  text: 'Избранное',
                  icon: Icons.favorite_outline,
                  onPressed: () {
                    // Логика для добавления в избранное
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Добавлено в избранное'),
                        backgroundColor: AppTheme.surfaceContainerHigh,
                      ),
                    );
                  },
                  style: NeonButtonStyle.outlined,
                  color: AppTheme.neonPink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isOwner() {
    if (_world == null) return false;
    // В MVP версии мы просто покажем кнопку редактирования для всех,
    // но в реальном приложении нужно проверять ID пользователя
    return true;
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
