import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  late final AnimationController _textController;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _textSlideAnimation;

  bool _showProgress = false;
  Timer? _progressTimer;
  Timer? _textTimer;
  bool _precached = false;

  @override
  void initState() {
    super.initState();

    // 1. Remove native splash once first frame is painted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // 2. Logo breath animation: 1.0 -> 1.04 -> 1.0 over 900ms (once)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _breatheAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 50,
      ),
    ]).animate(_breatheController);

    _breatheController.forward();

    // 3. Text entrance: fade in & move up 8dp, 300ms after logo
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textSlideAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textController.forward();
      }
    });

    // 4. Honey progress line: show only if loading takes longer than 1.2s
    _progressTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showProgress = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage('assets/images/auth_hero.jpg'), context);
      precacheImage(const AssetImage('assets/brand/logo_badge.png'), context);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _textTimer?.cancel();
    _breatheController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final centerY = screenHeight / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Subtle vertical gradient #24573A -> #173D22
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF24573A),
                        Color(0xFF173D22),
                      ],
                    ),
                  ),
                ),

                // 2. Faint radial highlight behind logo (white @ 6% opacity, radius 220)
                Positioned(
                  left: (screenWidth / 2) - 220,
                  top: centerY - 220,
                  width: 440,
                  height: 440,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          radius: 0.5,
                          colors: [
                            Colors.white.withValues(alpha: 0.06),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Centered logo at 112 dp with soft shadow and breathe animation
                // Exactly matching native splash center position
                Positioned(
                  left: (screenWidth - 112) / 2,
                  top: centerY - 56,
                  width: 112,
                  height: 112,
                  child: AnimatedBuilder(
                    animation: _breatheAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _breatheAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/logo_badge.png',
                        width: 112,
                        height: 112,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // 4. Wordmark & Tagline: 20dp gap below logo, fading in & sliding up 8dp
                Positioned(
                  left: 24,
                  right: 24,
                  top: centerY + 56 + 20,
                  child: AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'P.U.L.S.E.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lora(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Understanding Pollinators. Inspiring Action.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Honey progress line at bottom: 2px high, 120px long (#F4C542)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: SafeArea(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showProgress ? 1.0 : 0.0,
                        child: SizedBox(
                          width: 120,
                          height: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: const LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF4C542),
                              ),
                              backgroundColor: Colors.transparent,
                              minHeight: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
