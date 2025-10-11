import 'package:flutter/material.dart';
import 'package:loreshifter/core/theme/app_theme.dart';

class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool withGlow;
  final bool withAnimation;
  final BorderRadius? borderRadius;
  final Gradient? gradient;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.withGlow = false,
    this.withAnimation = true,
    this.borderRadius,
    this.gradient,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: AppTheme.fastCurve));

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.defaultCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.withAnimation) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.withAnimation) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.withAnimation) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin:
                widget.margin ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
              gradient: widget.gradient ?? AppTheme.subtleGradient,
              color:
                  widget.gradient == null
                      ? (widget.color ?? AppTheme.darkSurface)
                      : null,
              border: Border.all(
                color: AppTheme.outline.withAlpha(
                  widget.withGlow
                      ? (76 + (51 * _glowAnimation.value)).round()
                      : 76,
                ),
                width: 1,
              ),
              boxShadow: [
                if (widget.withGlow) ...[
                  ...AppTheme.neonShadow(
                    AppTheme.neonPurple,
                    intensity: 0.3 * _glowAnimation.value,
                  ),
                ] else ...[
                  ...AppTheme.cardShadow,
                ],
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
                child: Container(
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
