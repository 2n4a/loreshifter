import 'package:flutter/material.dart';
import 'package:loreshifter/core/theme/app_theme.dart';

class NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final ButtonSize size;
  final NeonButtonStyle style;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.size = ButtonSize.medium,
    this.style = NeonButtonStyle.filled,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

enum ButtonSize { small, medium, large }

enum NeonButtonStyle { filled, outlined, text, gradient }

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.defaultCurve),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.bounceCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  EdgeInsetsGeometry get _padding {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }

  Color get _buttonColor => widget.color ?? AppTheme.neonPurple;

  void _onTapDown() {
    _controller.forward();
  }

  void _onTapUp() {
    _controller.reverse();
  }

  Widget _buildButtonContent() {
    if (widget.isLoading) {
      return SizedBox(
        height: _iconSize,
        width: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color:
              widget.style == NeonButtonStyle.filled
                  ? Colors.white
                  : _buttonColor,
        ),
      );
    }

    final List<Widget> children = [];

    if (widget.icon != null) {
      children.add(
        Icon(
          widget.icon,
          size: _iconSize,
          color:
              widget.style == NeonButtonStyle.filled
                  ? Colors.white
                  : _buttonColor,
        ),
      );
      if (widget.text.isNotEmpty) {
        children.add(const SizedBox(width: 8));
      }
    }

    if (widget.text.isNotEmpty) {
      children.add(
        Text(
          widget.text,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color:
                widget.style == NeonButtonStyle.filled
                    ? Colors.white
                    : _buttonColor,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  widget.style == NeonButtonStyle.filled ||
                          widget.style == NeonButtonStyle.gradient
                      ? AppTheme.neonShadow(
                        _buttonColor,
                        intensity: 0.3 * _glowAnimation.value,
                      )
                      : null,
            ),
            child: _buildButton(),
          ),
        );
      },
    );
  }

  Widget _buildButton() {
    switch (widget.style) {
      case NeonButtonStyle.filled:
        return GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonColor,
              foregroundColor: Colors.white,
              padding: _padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _buildButtonContent(),
          ),
        );

      case NeonButtonStyle.outlined:
        return GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: OutlinedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _buttonColor,
              side: BorderSide(color: _buttonColor, width: 1.5),
              padding: _padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _buildButtonContent(),
          ),
        );

      case NeonButtonStyle.text:
        return GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: TextButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: TextButton.styleFrom(
              foregroundColor: _buttonColor,
              padding: _padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _buildButtonContent(),
          ),
        );

      case NeonButtonStyle.gradient:
        return GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.neonGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: _padding,
                  child: _buildButtonContent(),
                ),
              ),
            ),
          ),
        );
    }
  }
}
