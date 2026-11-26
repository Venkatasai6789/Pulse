import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/phi.dart';
import '../../../core/recommendations.dart';
import '../../../theme/app_theme.dart';

class RingGauge extends StatefulWidget {
  final int phi;
  final double size;
  final bool animate;

  const RingGauge({
    super.key,
    required this.phi,
    this.size = 110,
    this.animate = true,
  });

  @override
  State<RingGauge> createState() => _RingGaugeState();
}

class _RingGaugeState extends State<RingGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animate
          ? const Duration(milliseconds: 1000)
          : Duration.zero,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RingGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phi != widget.phi) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedPhi = widget.phi.clamp(0, 100);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final animatedScore = (_animation.value * clampedPhi).round();
        final progress = (_animation.value * clampedPhi) / 100.0;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingGaugePainter(
                  progress: progress,
                  tier: tierFor(clampedPhi),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clampedPhi == 0 ? '—' : '$animatedScore',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.0,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/100',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Tier tier;

  _RingGaugePainter({
    required this.progress,
    required this.tier,
  });

  // 5 Tier track colors
  static const _tierColors = [
    Color(0xFFD32F2F), // Investigate
    Color(0xFFE65100), // Restore
    Color(0xFFF57C00), // Improve
    Color(0xFF7CB342), // Enhance
    Color(0xFF1E4D2B), // Protect
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.095;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Start angle: 135 deg (bottom-left) to sweep 270 deg (ending at bottom-right)
    const startAngle = 135.0 * (pi / 180.0);
    const totalSweep = 270.0 * (pi / 180.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Draw subtle background segmented track (5 segments)
    const segmentSweep = totalSweep / 5.0;
    const gapAngle = 0.04; // small visual break between tier marks

    for (int i = 0; i < 5; i++) {
      final segStart = startAngle + i * segmentSweep + (gapAngle / 2);
      final segLength = segmentSweep - gapAngle;
      trackPaint.color = _tierColors[i].withValues(alpha: 0.16);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segStart,
        segLength,
        false,
        trackPaint,
      );
    }

    // 2. Draw active progress arc
    if (progress > 0) {
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = Color(tierInfo[tier]!.colorHex);

      final activeSweep = totalSweep * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tier != tier;
  }
}
