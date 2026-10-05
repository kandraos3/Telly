import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'telly_colors.dart';

/// Typography hierarchy definitions for Telly.
/// Defined according to `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §3.
abstract class TellyTypography {
  // Editorial Display Serif (Cinematic title cards, tier headers)
  static TextStyle displayXXL({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.playfairDisplay(
        fontSize: 38,
        height: 44 / 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.03 * 38,
        color: color,
      );

  static TextStyle displayXL({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.playfairDisplay(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * 28,
        color: color,
      );

  // Screen headers: tab screens (FE-HEADER-01) sit one step above pushed screens (FE-HEADER-02).
  static TextStyle screenTitle({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle subpageTitle({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color,
      );

  // Plus Jakarta Sans for UI & Metadata
  static TextStyle titleLarge({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01 * 22,
        color: color,
      );

  static TextStyle titleMedium({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle bodyLarge({Color color = TellyColors.textSecondary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle bodyMedium({Color color = TellyColors.textSecondary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle caption({Color color = TellyColors.textTertiary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        height: 15 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.02 * 11,
        color: color,
      );

  static TextStyle headlineSmall({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01 * 16,
        color: color,
      );

  static TextStyle labelLarge({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01 * 14,
        color: color,
      );

  static TextStyle labelMedium({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01 * 12,
        color: color,
      );

  static TextStyle labelSmall({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01 * 11,
        color: color,
      );

  static TextStyle monoDigits({Color color = TellyColors.phosphorLime}) =>
      scoreMono(color: color);

  // Tabular Figures for Live Decimal Scores (e.g. 9.85, 7.40)
  static TextStyle scoreHero({Color color = TellyColors.phosphorLime}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 32,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.04 * 32,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  static TextStyle scoreChip({Color color = TellyColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 1.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 14,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  static TextStyle scoreMono({Color color = TellyColors.phosphorLime}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );
}

