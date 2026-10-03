import 'package:flutter/material.dart';

/// Semantic and raw color tokens for the *Midnight Cathode* OLED design system.
/// Defined according to `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`.
abstract class TellyColors {
  // --- OLED Void Backgrounds & Surfaces ---
  static const Color backgroundPrimary = Color(0xFF08090C); // Void Canvas
  static const Color backgroundCanvasOled = Color(0xFF0A0A0C); // True OLED black
  static const Color backgroundSurface = Color(0xFF11131A); // Surface Raised (cards/nav)
  static const Color backgroundSurfaceAlt = Color(0xFF141419);
  static const Color backgroundCard = Color(0xFF1A1D27); // Surface Overlay (modals/popovers)
  static const Color backgroundCardAlt = Color(0xFF1C1C24);

  // --- Strokes & Glass Borders ---
  static const Color strokeSubtle = Color(0xFF242938);
  static const Color strokeStrong = Color(0xFF3D435C);
  static const Color borderGlass = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)

  // --- Primary Brand Accents ---
  static const Color phosphorLime = Color(0xFFD2FF52); // Primary CTA, winner states (#1)
  static const Color phosphorLimeAlt = Color(0xFFCCFF00); // Cathode variant
  static const Color neonCoral = Color(0xFFFF4B6E); // Upsets, spicy takes, dropped/DNF
  static const Color neonCoralAlt = Color(0xFFFF3366);
  static const Color warmAmber = Color(0xFFFFA733); // God tier badges, stars, gold foil
  static const Color warmAmberAlt = Color(0xFFFFB800);
  static const Color electricViolet = Color(0xFF7C5CFF); // Taste Match %, AI recs
  static const Color electricCyan = Color(0xFF00F0FF); // Streaming chips & highlights

  // --- Content & Typography ---
  static const Color textPrimary = Color(0xFFFFFFFF); // High-contrast headings
  static const Color textSecondary = Color(0xFFC8CAD8); // High-contrast body / reviews
  static const Color textTertiary = Color(0xFF7D8198); // Muted slate / timestamps
  static const Color textDisabled = Color(0xFF3D4259); // Faint / disabled states

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

