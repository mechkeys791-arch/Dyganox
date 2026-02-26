import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Fitness-inspired theme: red–dark purple gradient, neutrals, full ColorScheme.
///
/// - [fitnessGradient] — LinearGradient top-left to bottom-right (#C31432 → #D91E36 → #240B36, optional #3A0CA3).
/// - [fitnessGradientDecoration] — BoxDecoration for full-screen or container gradient.
/// - [chocolateTruffleTheme] — ThemeData (kept name for compatibility).
ThemeData get chocolateTruffleTheme => AppTheme().light;

/// Red-to-dark-purple gradient, top-left to bottom-right.
const LinearGradient fitnessGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    AppColors.fitnessRed,
    AppColors.fitnessRedBright,
    AppColors.fitnessDarkPurple,
    Color(0xFF3A0CA3), // optional purple
  ],
  stops: [0.0, 0.35, 0.7, 1.0],
);

/// BoxDecoration for gradient background (e.g. Scaffold body or full-screen Container).
BoxDecoration get fitnessGradientDecoration => const BoxDecoration(
      gradient: fitnessGradient,
    );

/// Wraps [child] in a [Container] with [fitnessGradientDecoration] behind it.
/// Use as Scaffold body: `body: FitnessGradientBackground(child: YourContent())`.
class FitnessGradientBackground extends StatelessWidget {
  const FitnessGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: fitnessGradientDecoration,
      child: child,
    );
  }
}

class AppTheme {
  ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: AppColors.fitnessDarkPurple,
      colorScheme: const ColorScheme.light(
        primary: AppColors.fitnessRed,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.fitnessRedBright,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.fitnessDarkPurple,
        onSecondary: AppColors.onSecondary,
        tertiary: AppColors.fitnessPurple,
        onTertiary: AppColors.onPrimary,
        surface: AppColors.neutralGray100,
        onSurface: AppColors.neutralGray900,
        surfaceContainerHighest: AppColors.neutralWhite,
        onSurfaceVariant: AppColors.neutralGray400,
        outline: AppColors.neutralGray400,
        error: AppColors.errorRed,
        onError: AppColors.neutralWhite,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColors.neutralGray900,
        displayColor: AppColors.neutralGray900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.neutralWhite),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.neutralWhite,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.fitnessRed,
          foregroundColor: AppColors.onPrimary,
          elevation: 8,
          shadowColor: AppColors.fitnessRed.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neutralWhite,
          side: const BorderSide(color: AppColors.neutralWhite),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: AppColors.neutralGray900.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: AppColors.neutralWhite,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutralWhite,
        hintStyle: TextStyle(color: AppColors.neutralGray400.withOpacity(0.9)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.neutralGray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.neutralGray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.fitnessRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.fitnessRed,
        foregroundColor: AppColors.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutralGray900,
        contentTextStyle: const TextStyle(color: AppColors.neutralWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.neutralGray200,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fitnessRed.withOpacity(0.15),
        selectedColor: AppColors.fitnessRed.withOpacity(0.35),
        labelStyle: const TextStyle(color: AppColors.neutralGray900),
        secondaryLabelStyle: const TextStyle(color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.neutralWhite,
        selectedItemColor: AppColors.fitnessRed,
        unselectedItemColor: AppColors.neutralGray400,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
