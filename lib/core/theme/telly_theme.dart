import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'telly_colors.dart';
import 'telly_typography.dart';

/// Master ThemeData configuration for Telly *Midnight Cathode* dark theme.
abstract class TellyTheme {
  static ThemeData get darkTheme => dark;
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
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: TellyColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: TellyColors.textPrimary),
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
}

