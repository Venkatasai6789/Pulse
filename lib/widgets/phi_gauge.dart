import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/phi.dart';
import '../core/recommendations.dart';
import '../theme/app_theme.dart';

/// Semicircle PHI Gauge with 5 tier segments, animated needle, arc, and count-up number.
class PhiGauge extends StatefulWidget {
  final int? phi;
  final double size;
  final bool animate;
  final String? label;
  final bool showNeedle;
  final VoidCallback? onTap;

  const PhiGauge({
    super.key,
    required this.phi,
    this.size = 220.0,
    this.animate = true,
    this.label = 'PHI',
    this.showNeedle = true,
    this.onTap,
  });

  @override
  State<PhiGauge> createState() => _PhiGaugeState();
}

class _PhiGaugeState extends State<PhiGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _prevPhi = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final target = (widget.phi ?? 0).toDouble();
    _animation = Tween<double>(
      begin: widget.animate ? 0.0 : target,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate && widget.phi != null) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 1.0;
    }
    _prevPhi = widget.phi ?? 0;
  }

  @override
  void didUpdateWidget(covariant PhiGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phi != oldWidget.phi) {
      final oldVal = (oldWidget.phi ?? _prevPhi).toDouble();
      final newVal = (widget.phi ?? 0).toDouble();
      _prevPhi = widget.phi ?? 0;

      if (widget.animate) {
        _animation = Tween<double>(
          begin: oldVal,
          end: newVal,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));
        _controller.forward(from: 0.0);
      } else {
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arcHeight = widget.size * 0.56;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final animatedValue = widget.phi == null
                  ? null
                  : (widget.animate ? _animation.value : widget.phi!.toDouble());

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: Size(widget.size, arcHeight),
                    painter: _PhiGaugePainter(
                      phiValue: animatedValue,
                      showNeedle: widget.showNeedle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  animatedValue == null
                      ? Text(
                          '—',
                          style: GoogleFonts.lora(
                            fontSize: widget.size * 0.18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${animatedValue.round()}',
                              style: GoogleFonts.lora(
                                fontSize: widget.size * 0.18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                ],
              );
            },
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.label!,
              style: GoogleFonts.inter(
                fontSize: widget.size * 0.065,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhiGaugePainter extends CustomPainter {
  final double? phiValue;
  final bool showNeedle;

  _PhiGaugePainter({
    required this.phiValue,
    required this.showNeedle,
  });

  // 5 Tiers in order: Investigate (0-19), Restore (20-39), Improve (40-59), Enhance (60-79), Protect (80-100)
  static final List<Color> _tierColors = [
    Color(tierInfo[Tier.investigate]!.colorHex),
    Color(tierInfo[Tier.restore]!.colorHex),
    Color(tierInfo[Tier.improve]!.colorHex),
    Color(tierInfo[Tier.enhance]!.colorHex),
    Color(tierInfo[Tier.protect]!.colorHex),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.11;
    final center = Offset(size.width / 2, size.height - (strokeWidth / 2) - 2);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = math.pi;
    const totalSweep = math.pi;
    const numSegments = 5;
    const gapAngle = 0.035; // thin gap between segments

    final segmentSweep = (totalSweep - (numSegments - 1) * gapAngle) / numSegments;

    // Draw background track when phi is null
    if (phiValue == null) {
      final bgPaint = Paint()
        ..color = AppColors.sageBorder.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep,
        false,
        bgPaint,
      );
      return;
    }

    // Draw 5 tier segments
    for (int i = 0; i < numSegments; i++) {
      final segStart = startAngle + i * (segmentSweep + gapAngle);
      final paint = Paint()
        ..color = _tierColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      // Round outer ends for first and last segments
      if (i == 0 || i == numSegments - 1) {
        paint.strokeCap = StrokeCap.round;
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segStart,
        segmentSweep,
        false,
        paint,
      );
    }

    // Draw needle
    if (showNeedle && phiValue != null) {
      final clamped = phiValue!.clamp(0.0, 100.0);
      final needleAngle = startAngle + (clamped / 100.0) * totalSweep;
      final needleLength = radius - strokeWidth * 0.45;

      final needlePaint = Paint()
        ..color = AppColors.forestDark
        ..style = PaintingStyle.fill;

      // Base polygon for tapered needle
      final perpendicular = needleAngle + math.pi / 2;
      const baseWidth = 5.0;

      final tip = Offset(
        center.dx + needleLength * math.cos(needleAngle),
        center.dy + needleLength * math.sin(needleAngle),
      );
      final p1 = Offset(
        center.dx + baseWidth * math.cos(perpendicular),
        center.dy + baseWidth * math.sin(perpendicular),
      );
      final p2 = Offset(
        center.dx - baseWidth * math.cos(perpendicular),
        center.dy - baseWidth * math.sin(perpendicular),
      );

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      canvas.drawPath(path, needlePaint);

      // Center pivot knob
      final knobPaint = Paint()
        ..color = AppColors.forestDark
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, strokeWidth * 0.35, knobPaint);

      final innerKnobPaint = Paint()
        ..color = AppColors.cream
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, strokeWidth * 0.15, innerKnobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PhiGaugePainter oldDelegate) {
    return oldDelegate.phiValue != phiValue || oldDelegate.showNeedle != showNeedle;
  }
}
