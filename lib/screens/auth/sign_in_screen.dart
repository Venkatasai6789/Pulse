import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_state.dart';
import '../../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  // 1. Ken Burns 14s zoom (1.0 -> 1.03)
  late final AnimationController _kenBurnsController;
  late final Animation<double> _kenBurnsAnimation;

  // 2. Coordinated entry animation (plays once)
  late final AnimationController _entryController;
  late final Animation<double> _heroFadeAnimation;
  late final Animation<double> _sheetFadeAnimation;
  late final Animation<double> _sheetSlideAnimation;
  late final Animation<double> _badgeScaleAnimation;
  late final Animation<double> _actionsFadeAnimation;

  // 3. Carousel
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;
  bool _isUserTouching = false;

  // 4. Gesture recognizers for legal text
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  static const _slides = [
    (
      headline: 'Measure pollinator health',
      subline: 'Record what you see and get a Pollinator Health Index in minutes.',
    ),
    (
      headline: 'Know what to do next',
      subline: 'Get clear, practical steps for your garden, school or society.',
    ),
    (
      headline: 'Grow with your community',
      subline: 'Share initiatives, join events and report concerns nearby.',
    ),
  ];

  static const _termsContent =
      'Welcome to P.U.L.S.E. (Pollinator Understanding, Logistics & Survey Ecosystem).\n\n'
      'By accessing or using our application, you agree to submit authentic pollinator and habitat observations to foster open biological conservation.\n\n'
      '1. Accurate Observation: Observations must represent true observations to preserve scientific data integrity.\n'
      '2. Community Respect: Share constructive and respectful comments on community posts.\n'
      '3. Non-Commercial: P.U.L.S.E. is dedicated to conservation research and community ecology education.';

  static const _privacyContent =
      'Privacy Policy for P.U.L.S.E.\n\n'
      'Your privacy is essential to our research community.\n\n'
      '• Information Collected: Account identifier, email, name, and submitted biodiversity assessment data.\n'
      '• Location Data: Optional geographic coordinates are gathered only when you explicitly register a monitoring site.\n'
      '• Data Usage: Aggregated scores inform community pollinator conservation and health trends.\n'
      '• No Selling: We will never monetize or sell personal identity data.';

  @override
  void initState() {
    super.initState();

    // 14s Ken Burns zoom (1.0 -> 1.03, reverse repeating)
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _kenBurnsAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );

    // Entry animations (total 800ms)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Hero fade in (0 -> 400ms)
    _heroFadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    // Sheet slide up 24dp + fade (100ms -> 550ms, easeOutCubic)
    _sheetFadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.125, 0.6875, curve: Curves.easeOutCubic),
    );
    _sheetSlideAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.125, 0.6875, curve: Curves.easeOutCubic),
      ),
    );

    // Logo badge scale 0.8 -> 1.0 with overshoot (100ms -> 600ms, easeOutBack)
    _badgeScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.125, 0.75, curve: Curves.easeOutBack),
      ),
    );

    // Buttons fade in last (350ms -> 750ms)
    _actionsFadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.4375, 0.9375, curve: Curves.easeOut),
    );

    _pageController = PageController();
    _startCarouselTimer();

    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showStaticDoc('Terms of Service', _termsContent);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showStaticDoc('Privacy Policy', _privacyContent);

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnimations) {
        _entryController.value = 1.0;
      } else {
        _entryController.forward();
        _kenBurnsController.repeat(reverse: true);
      }
    });
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
      if (!mounted || _isUserTouching) return;
      final nextPage = (_currentPage + 1) % _slides.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _kenBurnsController.dispose();
    _entryController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showStaticDoc(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isSigningIn = auth.isLoading;
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final isSmall = screenHeight < 700;

    // Small screens: hero 48%, otherwise 58%
    final heroHeight = screenHeight * (isSmall ? 0.48 : 0.58);
    // Sheet starts at 54% (44% on small screens) to overlap bottom of hero
    final sheetTop = screenHeight * (isSmall ? 0.44 : 0.54);

    const badgeDiameter = 84.0; // 76dp badge + 4dp cream ring on each side
    final badgeTop = sheetTop - (badgeDiameter / 2);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6EC),
        body: Stack(
          children: [
            // 1. Hero Photo area (top 58% or 48%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: AnimatedBuilder(
                animation: _heroFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heroFadeAnimation.value,
                    child: child,
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Zooming background image (1.0 -> 1.03)
                    ClipRect(
                      child: AnimatedBuilder(
                        animation: _kenBurnsAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _kenBurnsAnimation.value,
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/auth_hero.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.2),
                              filterQuality: FilterQuality.high,
                            ),
                          );
                        },
                      ),
                    ),

                    // Top vignette (black 35% -> transparent, 120 dp)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x59000000), // black 35%
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom vignette (transparent -> black 20%, bottom 30%)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: heroHeight * 0.30,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x33000000), // black 20%
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Content sheet (starts at sheetTop, top corners radius 32, upward shadow)
            Positioned(
              top: sheetTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _entryController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _sheetFadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _sheetSlideAnimation.value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6EC),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top scrollable portion (sticker clearance, wordmark, carousel)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Clearance below sticker: half badge (42dp) + 12dp gap = 54dp
                              const SizedBox(height: 52),

                              // Wordmark "P.U.L.S.E."
                              Text(
                                'P.U.L.S.E.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lora(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E4D2B),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Sub-label "POLLINATOR HEALTH INDEX"
                              Text(
                                'POLLINATOR HEALTH INDEX',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF687364),
                                  letterSpacing: 0.8,
                                ),
                              ),

                              // Gap 24dp to carousel
                              const SizedBox(height: 24),

                              // Value Carousel (padding 28dp, fixed height)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Column(
                                  children: [
                                    Listener(
                                      onPointerDown: (_) =>
                                          setState(() => _isUserTouching = true),
                                      onPointerUp: (_) =>
                                          setState(() => _isUserTouching = false),
                                      onPointerCancel: (_) =>
                                          setState(() => _isUserTouching = false),
                                      child: SizedBox(
                                        height: isSmall ? 64 : 100,
                                        child: PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentPage = index;
                                            });
                                          },
                                          itemCount: _slides.length,
                                          itemBuilder: (context, index) {
                                            final slide = _slides[index];
                                            return Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  slide.headline,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.lora(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF1F241D),
                                                    height: 1.2,
                                                  ),
                                                ),
                                                if (!isSmall) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    slide.subline,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w400,
                                                      color: const Color(0xFF687364),
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Dot indicators: active 20x6 pill, inactive 6x6
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(_slides.length, (index) {
                                        final isActive = _currentPage == index;
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: isActive ? 20 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFF1E4D2B)
                                                : const Color(0xFFCFDDBF),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Actions pinned to bottom with entry fade animation
                      AnimatedBuilder(
                        animation: _actionsFadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _actionsFadeAnimation.value,
                            child: child,
                          );
                        },
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Error Banner card if error exists
                                if (auth.error != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDECEA),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.alert.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.alert,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            auth.error!,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.alert,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: isSigningIn
                                              ? null
                                              : () => auth.signInWithGoogle(),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(48, 32),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Retry',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.alert,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Continue with Google Button (height 54, radius 27, shadow)
                                Container(
                                  height: 54,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(27),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: OutlinedButton(
                                    onPressed: isSigningIn
                                        ? null
                                        : () {
                                            HapticFeedback.lightImpact();
                                            auth.signInWithGoogle();
                                          },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1F1F1F),
                                      side: const BorderSide(
                                        color: Color(0xFF747775),
                                        width: 1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(27),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: isSigningIn
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF1F1F1F),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Signing in…',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF1F1F1F),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/icon/google_g.svg',
                                                width: 20,
                                                height: 20,
                                                placeholderBuilder: (_) =>
                                                    const Icon(
                                                  Icons.account_circle,
                                                  size: 20,
                                                  color: Color(0xFF4285F4),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Continue with Google',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF1F1F1F),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Thin divider row with "or" in middle
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFFD6DEC9),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'or',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF687364),
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFFD6DEC9),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // "Explore the demo" secondary button (height 48)
                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: isSigningIn
                                        ? null
                                        : () {
                                            HapticFeedback.lightImpact();
                                            auth.signInGuest();
                                          },
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: Color(0xFF1E4D2B),
                                    ),
                                    label: Text(
                                      'Explore the demo',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E4D2B),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Legal line: "By continuing you agree to our Terms and Privacy Policy"
                                Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'By continuing you agree to our ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF687364),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Terms',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E4D2B),
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: _termsRecognizer,
                                        ),
                                        TextSpan(
                                          text: ' and ',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF687364),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E4D2B),
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: _privacyRecognizer,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Logo Lockup centered on the sheet edge (sticker effect)
            Positioned(
              top: badgeTop,
              left: (screenWidth - badgeDiameter) / 2,
              width: badgeDiameter,
              height: badgeDiameter,
              child: AnimatedBuilder(
                animation: _badgeScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _badgeScaleAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: badgeDiameter,
                  height: badgeDiameter,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6EC), // 4dp cream ring
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4), // 4dp cream ring
                  child: Image.asset(
                    'assets/brand/logo_badge.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
