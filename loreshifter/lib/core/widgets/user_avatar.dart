import 'package:flutter/material.dart';
import 'package:loreshifter/core/theme/app_theme.dart';

class UserAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool withBorder;
  final bool withGlow;
  final VoidCallback? onTap;
  final Color? glowColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.withBorder = true,
    this.withGlow = false,
    this.onTap,
    this.glowColor,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.bounceCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _initials {
    final words = widget.name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  Color get _glowColor => widget.glowColor ?? AppTheme.neonBlue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    widget.withBorder
                        ? Border.all(color: _glowColor, width: 2)
                        : null,
                boxShadow:
                    widget.withGlow
                        ? AppTheme.neonShadow(_glowColor, intensity: 0.5)
                        : [
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
              ),
              child: ClipOval(
                child:
                    widget.imageUrl != null
                        ? Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildFallbackAvatar();
                          },
                        )
                        : _buildFallbackAvatar(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_glowColor.withAlpha(127), _glowColor.withAlpha(76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: AppTheme.neonTextStyle(
            color: Colors.white,
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            intensity: 0.3,
          ),
        ),
      ),
    );
  }
}
