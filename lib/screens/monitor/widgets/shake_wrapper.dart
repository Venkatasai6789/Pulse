import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShakeWrapper extends StatefulWidget {
  final Widget child;

  const ShakeWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ShakeWrapper> createState() => ShakeWrapperState();
}

class ShakeWrapperState extends State<ShakeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    if (mounted) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // 3 oscillations fading out
        final progress = _animation.value;
        final offset = 10.0 *
            (1.0 - progress) *
            math.sin(progress * 6 * math.pi);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
