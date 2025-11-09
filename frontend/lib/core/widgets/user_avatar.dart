import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.glowColor ?? cs.primary;

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
                        ? Border.all(
                          color: accent.withValues(alpha: 0.7),
                          width: 1.5,
                        )
                        : null,
                boxShadow: [
                  BoxShadow(
                    color:
                        widget.withGlow
                            ? accent.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.06),
                    blurRadius: widget.withGlow ? 14 : 8,
                    offset: const Offset(0, 3),
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
                            return _buildFallbackAvatar(accent, cs);
                          },
                        )
                        : _buildFallbackAvatar(accent, cs),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackAvatar(Color accent, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
