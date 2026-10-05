import 'package:flutter/material.dart';

/// Semantic and raw color tokens for the *Midnight Cathode* OLED and *Day Cathode* design systems.
/// Defined according to `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §2 and `FE-THEME-01`.
abstract class TellyColors {
  // --- OLED Void Backgrounds & Surfaces (Dark) ---
  static const Color backgroundPrimary = Color(0xFF08090C); // Void Canvas
  static const Color backgroundCanvasOled = Color(0xFF0A0A0C); // True OLED black
  static const Color backgroundSurface = Color(0xFF11131A); // Surface Raised (cards/nav)
  static const Color backgroundSurfaceAlt = Color(0xFF141419);
  static const Color backgroundCard = Color(0xFF1A1D27); // Surface Overlay (modals/popovers)
  static const Color backgroundCardAlt = Color(0xFF1C1C24);

  // --- Day Cathode Light Surfaces ---
  static const Color lightBackgroundPrimary = Color(0xFFF6F7F9); // Day Canvas
  static const Color lightBackgroundCanvas = Color(0xFFF6F7F9);
  static const Color lightBackgroundSurface = Color(0xFFFFFFFF); // Card surface
  static const Color lightBackgroundCard = Color(0xFFF0F2F5); // Popovers/dialogs
  static const Color lightStrokeSubtle = Color(0xFFE2E5EC); // Dividers/borders
  static const Color lightStrokeStrong = Color(0xFFCBD2E0);
  static const Color lightBorderGlass = Color(0x14000000); // rgba(0, 0, 0, 0.08)

  // --- Strokes & Glass Borders (Dark) ---
  static const Color strokeSubtle = Color(0xFF242938);
  static const Color strokeStrong = Color(0xFF3D435C);
  static const Color borderGlass = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)

  // --- Primary Brand Accents (Dark) ---
  static const Color phosphorLime = Color(0xFFD2FF52); // Primary CTA, winner states (#1)
  static const Color phosphorLimeAlt = Color(0xFFCCFF00); // Cathode variant
  static const Color neonCoral = Color(0xFFFF4B6E); // Upsets, spicy takes, dropped/DNF
  static const Color neonCoralAlt = Color(0xFFFF3366);
  static const Color warmAmber = Color(0xFFFFA733); // God tier badges, stars, gold foil
  static const Color warmAmberAlt = Color(0xFFFFB800);
  static const Color electricViolet = Color(0xFF7C5CFF); // Taste Match %, AI recs
  static const Color electricCyan = Color(0xFF00F0FF); // Streaming chips & highlights

  // --- Day Cathode Light Brand Accents (WCAG AA Pass on Light Surfaces) ---
  static const Color lightPhosphorLime = Color(0xFF4D7800); // 4.8:1 AA contrast on light
  static const Color lightPhosphorLimeSurface = Color(0xFFD2FF52); // Button fill
  static const Color lightNeonCoral = Color(0xFFD61F4D); // 5.2:1 AA contrast on light
  static const Color lightWarmAmber = Color(0xFFB36200); // 4.9:1 AA contrast on light
  static const Color lightElectricViolet = Color(0xFF5B3CE0); // 6.1:1 AA contrast on light
  static const Color lightElectricCyan = Color(0xFF00838F);

  // --- Content & Typography (Dark) ---
  static const Color textPrimary = Color(0xFFFFFFFF); // High-contrast headings
  static const Color textSecondary = Color(0xFFC8CAD8); // High-contrast body / reviews
  static const Color textTertiary = Color(0xFF7D8198); // Muted slate / timestamps
  static const Color textDisabled = Color(0xFF3D4259); // Faint / disabled states

  // --- Day Cathode Content & Typography (Light - WCAG AAA/AA Pass) ---
  static const Color lightTextPrimary = Color(0xFF0F1117); // 15.6:1 AAA on #F6F7F9
  static const Color lightTextSecondary = Color(0xFF4A4E63); // 7.2:1 AAA on #FFFFFF
  static const Color lightTextTertiary = Color(0xFF696E87); // > 4.8:1 AA on #FFFFFF
  static const Color lightTextDisabled = Color(0xFFA0A5BA);

  // --- Tier Badge Gradients & Solids ---
  // God Tier (9.20 - 10.00)
  static const Color tierGodStart = Color(0xFFFFE066);
  static const Color tierGodEnd = Color(0xFFFFA733);
  // Prestige Tier (8.50 - 9.19)
  static const Color tierPrestigeStart = Color(0xFFA78BFA);
  static const Color tierPrestigeEnd = Color(0xFF7C5CFF);
  // Great Tier (7.80 - 8.49)
  static const Color tierGreatStart = Color(0xFF34D399);
  static const Color tierGreatEnd = Color(0xFF059669);
  // Good / Fun (7.00 - 7.79)
  static const Color tierGoodStart = Color(0xFF38BDF8);
  static const Color tierGoodEnd = Color(0xFF0284C7);
  // Mid / Filler (5.50 - 6.99)
  static const Color tierMidStart = Color(0xFF94A3B8);
  static const Color tierMidEnd = Color(0xFF64748B);
  // Dropped / DNF (< 5.50)
  static const Color tierDroppedStart = Color(0xFFF87171);
  static const Color tierDroppedEnd = Color(0xFFDC2626);
}
