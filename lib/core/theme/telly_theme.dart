import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'telly_colors.dart';
import 'telly_typography.dart';

/// Master ThemeData configuration for Telly *Midnight Cathode* (Dark) and *Day Cathode* (Light) themes.
/// Conforms to `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §2 and `FE-THEME-01`.
abstract class TellyTheme {
  static ThemeData get darkTheme => dark;
  static ThemeData get lightTheme => light;

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: TellyColors.phosphorLime,
      secondary: TellyColors.neonCoral,
      tertiary: TellyColors.warmAmber,
      surface: TellyColors.backgroundSurface,
      error: TellyColors.neonCoral,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: TellyColors.textPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TellyColors.backgroundPrimary,
      canvasColor: TellyColors.backgroundPrimary,
      cardColor: TellyColors.backgroundSurface,
      cardTheme: CardThemeData(
        color: TellyColors.backgroundSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TellyColors.borderGlass),
        ),
      ),
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: TellyColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: TellyColors.textPrimary),
        titleTextStyle: TextStyle(
          color: TellyColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: TellyColors.strokeSubtle,
      dividerTheme: const DividerThemeData(
        color: TellyColors.strokeSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TellyColors.backgroundCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TellyTypography.displayXXL(),
        displayMedium: TellyTypography.displayXL(),
        titleLarge: TellyTypography.titleLarge(),
        titleMedium: TellyTypography.titleMedium(),
        bodyLarge: TellyTypography.bodyLarge(),
        bodyMedium: TellyTypography.bodyMedium(),
        labelSmall: TellyTypography.caption(),
      ),
    );
  }

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: TellyColors.lightPhosphorLime,
      secondary: TellyColors.lightNeonCoral,
      tertiary: TellyColors.lightWarmAmber,
      surface: TellyColors.lightBackgroundSurface,
      error: TellyColors.lightNeonCoral,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: TellyColors.lightTextPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TellyColors.lightBackgroundPrimary,
      canvasColor: TellyColors.lightBackgroundPrimary,
      cardColor: TellyColors.lightBackgroundSurface,
      cardTheme: CardThemeData(
        color: TellyColors.lightBackgroundSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TellyColors.lightStrokeSubtle),
        ),
      ),
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: TellyColors.lightBackgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: TellyColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: TellyColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: TellyColors.lightStrokeSubtle,
      dividerTheme: const DividerThemeData(
        color: TellyColors.lightStrokeSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TellyColors.lightBackgroundSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TellyTypography.displayXXL(color: TellyColors.lightTextPrimary),
        displayMedium: TellyTypography.displayXL(color: TellyColors.lightTextPrimary),
        titleLarge: TellyTypography.titleLarge(color: TellyColors.lightTextPrimary),
        titleMedium: TellyTypography.titleMedium(color: TellyColors.lightTextPrimary),
        bodyLarge: TellyTypography.bodyLarge(color: TellyColors.lightTextPrimary),
        bodyMedium: TellyTypography.bodyMedium(color: TellyColors.lightTextSecondary),
        labelSmall: TellyTypography.caption(color: TellyColors.lightTextTertiary),
      ),
    );
  }
}
