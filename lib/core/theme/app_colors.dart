import 'package:flutter/material.dart';

/// Fitness-inspired palette: bold red-to-dark-purple gradient + neutrals.
///
/// **Gradient colors (top-left → bottom-right):**
/// - [fitnessRed] #C31432 — Bold red (gradient start).
/// - [fitnessRedBright] #D91E36 — Bright red (mid).
/// - [fitnessDarkPurple] #240B36 — Dark purple (gradient end).
/// - [fitnessPurple] #3A0CA3 — Optional purple (accent).
///
/// **Neutrals:**
/// - [neutralWhite] #FFFFFF
/// - [neutralGray100] #F5F5F5
/// - [neutralGray200] #E0E0E0
/// - [neutralGray400] #9E9E9E
/// - [neutralGray900] #222222
class AppColors {
  AppColors._();

  // ---- Gradient palette ----
  static const Color fitnessRed = Color(0xFFC31432);
  static const Color fitnessRedBright = Color(0xFFD91E36);
  static const Color fitnessDarkPurple = Color(0xFF240B36);
  static const Color fitnessPurple = Color(0xFF3A0CA3);

  // ---- Neutrals ----
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color neutralGray100 = Color(0xFFF5F5F5);
  static const Color neutralGray200 = Color(0xFFE0E0E0);
  static const Color neutralGray400 = Color(0xFF9E9E9E);
  static const Color neutralGray900 = Color(0xFF222222);

  // ---- Semantic (gradient / dark surfaces) ----
  static const Color onGradient = neutralWhite;
  static const Color onPrimary = neutralWhite;
  static const Color onSecondary = neutralWhite;

  // ---- Mapped names (existing app code) ----
  static const Color burntOrange = fitnessRed;
  static const Color warmBrown = fitnessDarkPurple;
  static const Color cream = neutralGray100;
  static const Color darkChocolate = neutralGray900;
  static const Color onWarmBrown = neutralWhite;
  static const Color onBurntOrange = neutralWhite;
  static const Color onCream = neutralGray900;
  static const Color onDarkChocolate = neutralWhite;
  static const Color creamElevated = neutralWhite;
  static const Color warmBrownMuted = neutralGray400;
  static const Color warmAmber = fitnessRedBright;
  static const Color errorRed = Color(0xFFB91C1C);
  static const Color onBlack = neutralWhite;
  static const Color black = neutralGray900;
  static const Color pureYellow = neutralGray100;
  static const Color neonYellowGreen = fitnessRed;
  static const Color onYellow = neutralGray900;
}
