import 'package:flutter/material.dart';
import '../../hardware/models/node_connection.dart';
import '../../theme/app_theme.dart';

/// An 8 dp circle plus an optional status word, ensuring status is never colour-only.
class SensorStatusDot extends StatefulWidget {
  final NodeConnection state;
  final bool showLabel;
  final TextStyle? labelStyle;

  const SensorStatusDot({
    super.key,
    required this.state,
    this.showLabel = true,
    this.labelStyle,
  });

  @override
  State<SensorStatusDot> createState() => _SensorStatusDotState();
}

class _SensorStatusDotState extends State<SensorStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.state == NodeConnection.searching) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SensorStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == NodeConnection.searching) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.state) {
      case NodeConnection.online:
        return AppColors.leaf;
      case NodeConnection.stale:
      case NodeConnection.searching:
        return AppColors.honey;
      case NodeConnection.offline:
      case NodeConnection.notPaired:
        return AppColors.muted;
      case NodeConnection.fault:
      case NodeConnection.unauthorized:
        return AppColors.alert;
    }
  }

  String get _label {
    switch (widget.state) {
      case NodeConnection.online:
        return 'Live';
      case NodeConnection.stale:
        return 'Delayed';
      case NodeConnection.searching:
        return 'Connecting';
      case NodeConnection.offline:
        return 'Offline';
      case NodeConnection.fault:
        return 'Probe fault';
      case NodeConnection.unauthorized:
        return 'Pair again';
      case NodeConnection.notPaired:
        return 'Not paired';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );

    final animatedDot = widget.state == NodeConnection.searching
        ? FadeTransition(opacity: _pulseAnimation, child: dot)
        : dot;

    if (!widget.showLabel) {
      return animatedDot;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        animatedDot,
        const SizedBox(width: 6),
        Text(
          _label,
          style: widget.labelStyle ??
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _color,
              ),
        ),
      ],
    );
  }
}
