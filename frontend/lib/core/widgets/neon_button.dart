import 'package:flutter/material.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final ButtonSize size;
  final NeonButtonStyle style;
  final Gradient? gradient;
  final double glowIntensity;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.size = ButtonSize.medium,
    this.style = NeonButtonStyle.filled,
    this.gradient,
    this.glowIntensity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case NeonButtonStyle.filled:
        return _buildElevated(context);
      case NeonButtonStyle.outlined:
        return _buildOutlined(context);
      case NeonButtonStyle.text:
        return _buildText(context);
      case NeonButtonStyle.gradient:
        return _buildGradient(context);
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double get _fontSize {
    switch (size) {
      case ButtonSize.small:
        return 13;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.small:
        return 18;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 22;
    }
  }

  Color _accent(BuildContext context) =>
      color ?? Theme.of(context).colorScheme.primary;

  Widget _content(BuildContext context, {required Color textColor}) {
    final children = <Widget>[];
    if (isLoading) {
      return SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
      );
    }
    if (icon != null) {
      children.add(Icon(icon, size: _iconSize, color: textColor));
      if (text.isNotEmpty) children.add(const SizedBox(width: 8));
    }
    if (text.isNotEmpty) {
      children.add(
        Text(
          text,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildElevated(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent(context),
        foregroundColor: cs.onPrimary,
        padding: _padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _content(context, textColor: cs.onPrimary),
    );
  }

  Widget _buildOutlined(BuildContext context) {
    final acc = _accent(context);
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: acc,
        side: BorderSide(color: acc, width: 1),
        padding: _padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _content(context, textColor: acc),
    );
  }

  Widget _buildText(BuildContext context) {
    final acc = _accent(context);
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: acc,
        padding: _padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _content(context, textColor: acc),
    );
  }

  Widget _buildGradient(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grad =
        gradient ??
        LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: _padding,
            child: Center(child: _content(context, textColor: Colors.white)),
          ),
        ),
      ),
    );
  }
}

enum ButtonSize { small, medium, large }

enum NeonButtonStyle { filled, outlined, text, gradient }
