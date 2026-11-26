import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours sampled from the P.U.L.S.E. designs.
class AppColors {
  static const forest = Color(0xFF1E4D2B); // sidebar / nav / headers
  static const forestDark = Color(0xFF173D22); // primary buttons
  static const leaf = Color(0xFF3E8E3A); // gauge, progress bars
  static const leafLight = Color(0xFF7CB342);
  static const sage = Color(0xFFE3EDD6); // chips, soft panels
  static const sageBorder = Color(0xFFCFDDBF);
  static const cream = Color(0xFFFAF6EC); // page background
  static const card = Color(0xFFFFFDF7); // card background
  static const ink = Color(0xFF1F2A1F); // main text
  static const muted = Color(0xFF5C6B5C); // secondary text
  static const honey = Color(0xFFF4C542); // gauge yellow
  static const alert = Color(0xFFC62828); // risk alert
  static const alertSoft = Color(0xFFFDECEA);
}

class AppRadius {
  static const card = 20.0;
  static const chip = 12.0;
  static const button = 28.0;
}

class AppTheme {
  /// Headings: Lora (bold serif, close to the designs). Body: Inter.
  /// google_fonts downloads fonts on first run. For a fully offline APK,
  /// bundle the .ttf files in assets/google_fonts/ (see README).
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.forest);
    final body = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    TextStyle serif(double size, [FontWeight w = FontWeight.w700]) =>
        GoogleFonts.lora(fontSize: size, fontWeight: w, color: AppColors.forest);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.forestDark,
        secondary: AppColors.leaf,
        surface: AppColors.card,
        error: AppColors.alert,
      ),
      textTheme: body.copyWith(
        displayLarge: serif(48),
        displayMedium: serif(40),
        headlineLarge: serif(28),
        headlineMedium: serif(24),
        headlineSmall: serif(20),
        titleLarge: serif(18),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.sageBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppColors.sageBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppColors.sageBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppColors.leaf, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forestDark,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.forestDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.forest,
        indicatorColor: AppColors.leaf.withValues(alpha: 0.35),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.sage,
        selectedColor: AppColors.forestDark,
        side: const BorderSide(color: AppColors.sageBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
    );
  }
}
