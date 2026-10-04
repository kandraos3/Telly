@Tags(['a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import '../fakes/fake_auth_repository.dart';

void main() {
  group('WCAG 2.1 AA Accessibility & Semantics Audit (QA-503)', () {
    testWidgets('TellyPrimaryButton meets 48x48dp minimum tap target guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Center(
              child: TellyPrimaryButton(
                label: 'Confirm Selection',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check minimum touch size
      final buttonSize = tester.getSize(find.byType(TellyPrimaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));

      // Check tap target guideline
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('Interactive IconButtons have non-empty semanticsLabel or tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close modal',
                onPressed: () {},
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share story',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeButton.tooltip, isNotNull);
      expect(closeButton.tooltip, isNotEmpty);

      final shareButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.share));
      expect(shareButton.tooltip, isNotNull);
      expect(shareButton.tooltip, isNotEmpty);
    });

    testWidgets('Text contrast on OLED black background exceeds WCAG 4.5:1 ratio', (tester) async {
      // OLED Background: #0A0A0C
      const bg = TellyColors.backgroundCanvasOled;
      // Primary text: #FFFFFF
      const fg = TellyColors.textPrimary;

      // Relative luminance calculation
      final lBg = bg.computeLuminance();
      final lFg = fg.computeLuminance();
      final contrastRatio = (lFg + 0.05) / (lBg + 0.05);

      // WCAG AA requirement for normal text is 4.5:1
      expect(contrastRatio, greaterThan(4.5));
      // For pure white on OLED black, contrast ratio is typically > 18:1
      expect(contrastRatio, greaterThan(15.0));
    });

    testWidgets('Screen A11y Audit: SCR-01 AuthScreen meets all guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: MaterialApp(
            theme: TellyTheme.darkTheme,
            home: const AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
