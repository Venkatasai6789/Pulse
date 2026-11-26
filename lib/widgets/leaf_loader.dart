import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small animated leaf spinner used across loading states.
class LeafLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final String? message;

  const LeafLoader({
    super.key,
    this.size = 48.0,
    this.color,
    this.message,
  });

  @override
  State<LeafLoader> createState() => _LeafLoaderState();
}

class _LeafLoaderState extends State<LeafLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leafColor = widget.color ?? AppColors.leaf;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Stack(
                    alignment: Alignment.center,
                    children: List.generate(4, (index) {
                      final angle = index * (math.pi / 2);
                      final opacity = 0.3 + 0.7 * ((index + _controller.value * 4) % 4) / 4;
                      return Transform.rotate(
                        angle: angle,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.eco_rounded,
                            size: widget.size * 0.45,
                            color: leafColor.withValues(alpha: opacity.clamp(0.2, 1.0)),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
