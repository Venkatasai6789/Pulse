import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Standard card widget following P.U.L.S.E. styling.
class PulseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final double borderRadius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final Clip clipBehavior;

  const PulseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.borderRadius = AppRadius.card,
    this.onTap,
    this.shadows,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.sageBorder;
    final effectiveRadius = BorderRadius.circular(borderRadius);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth ?? 1.0,
        ),
        boxShadow: shadows,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return PressableScale(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
