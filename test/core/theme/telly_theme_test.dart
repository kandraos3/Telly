import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/theme/telly_typography.dart';

double _linearize(double c) {
  return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('TellyColors Contrast Ratios (WCAG AA & AAA Verification)', () {
    const oledBg = Color(0xFF0A0A0C);
    const canvasBg = TellyColors.backgroundPrimary; // #08090C

    test('Phosphor Lime contrast against dark background exceeds 4.5:1', () {
      final ratioOled = _contrastRatio(TellyColors.phosphorLime, oledBg);
      final ratioCanvas = _contrastRatio(TellyColors.phosphorLime, canvasBg);

      expect(ratioOled, greaterThanOrEqualTo(4.5));
      expect(ratioCanvas, greaterThanOrEqualTo(4.5));
    });

    test('Neon Coral contrast against dark background exceeds 4.5:1', () {
      final ratioOled = _contrastRatio(TellyColors.neonCoral, oledBg);
      final ratioCanvas = _contrastRatio(TellyColors.neonCoral, canvasBg);

      expect(ratioOled, greaterThanOrEqualTo(4.5));
      expect(ratioCanvas, greaterThanOrEqualTo(4.5));
    });

    test('Text Primary (white) contrast against canvas exceeds 15:1', () {
      final ratio = _contrastRatio(TellyColors.textPrimary, canvasBg);
      expect(ratio, greaterThan(15.0));
    });
  });

  group('TellyTheme & Typography Sandbox Widget Tests', () {
    testWidgets('Renders all typography presets without rendering errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Display XXL', style: TellyTypography.displayXXL()),
                  Text('Display XL', style: TellyTypography.displayXL()),
                  Text('Title Large', style: TellyTypography.titleLarge()),
                  Text('Title Medium', style: TellyTypography.titleMedium()),
                  Text('Body Large', style: TellyTypography.bodyLarge()),
                  Text('Body Medium', style: TellyTypography.bodyMedium()),
                  Text('Caption', style: TellyTypography.caption()),
                  Text('9.85', style: TellyTypography.scoreHero()),
                  Text('8.50', style: TellyTypography.scoreChip()),
                  Text('Score Mono', style: TellyTypography.scoreMono()),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Display XXL'), findsOneWidget);
      expect(find.text('Display XL'), findsOneWidget);
      expect(find.text('Title Large'), findsOneWidget);
      expect(find.text('Title Medium'), findsOneWidget);
      expect(find.text('Body Large'), findsOneWidget);
      expect(find.text('Body Medium'), findsOneWidget);
      expect(find.text('Caption'), findsOneWidget);
      expect(find.text('9.85'), findsOneWidget);
      expect(find.text('8.50'), findsOneWidget);
      expect(find.text('Score Mono'), findsOneWidget);
    });
  });
}
