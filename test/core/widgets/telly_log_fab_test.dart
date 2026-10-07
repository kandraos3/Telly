import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_floating_nav_bar.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';

void main() {
  Future<List<String>> pumpFab(WidgetTester tester, {ThemeData? theme}) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? TellyTheme.dark,
      home: Scaffold(
        body: Center(child: TellyLogFab(onTap: () => taps.add('log'))),
      ),
    ));
    return taps;
  }

  BoxDecoration decoOf(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const Key('log_fab'))).decoration! as BoxDecoration;

  group('#113: TellyLogFab (component spec §2.3)', () {
    testWidgets('is a 52-tall lime pill with a Void + and "Log"', (tester) async {
      await pumpFab(tester);
      expect(tester.getSize(find.byKey(const Key('log_fab'))).height, 52);
      final deco = decoOf(tester);
      expect(deco.color, TellyColors.phosphorLime);
      expect(deco.borderRadius, BorderRadius.circular(999));
      expect(find.text('Log'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Log')).style!.color, TellyColors.backgroundPrimary);
      expect(tester.widget<Text>(find.text('Log')).style!.fontWeight, FontWeight.w700);
      final icon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(icon.size, 20);
      expect(icon.color, TellyColors.backgroundPrimary);
    });

    testWidgets('has a 20px lime halo at 35% in dark mode', (tester) async {
      await pumpFab(tester);
      final shadow = decoOf(tester).boxShadow!.single;
      expect(shadow.blurRadius, 20);
      expect(shadow.color, TellyColors.phosphorLime.withValues(alpha: 0.35));
    });

    testWidgets('keeps lime and Void text but drops the halo in light mode', (tester) async {
      await pumpFab(tester, theme: TellyTheme.light);
      final deco = decoOf(tester);
      expect(deco.color, TellyColors.phosphorLime);
      expect(deco.boxShadow, isNull);
      expect(tester.widget<Text>(find.text('Log')).style!.color, TellyColors.backgroundPrimary);
    });

    testWidgets('tap fires the callback with a medium haptic', (tester) async {
      final haptics = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String?);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final taps = await pumpFab(tester);
      await tester.tap(find.byKey(const Key('log_fab')));
      expect(taps, ['log']);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('is announced as one "Log a title" button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFab(tester);
      expect(
        tester.getSemantics(find.byKey(const Key('log_fab'))),
        isSemantics(label: 'Log a title', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('sits 16 above the nav bar, clearing the safe area', (tester) async {
      late double offset;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Builder(builder: (context) {
          offset = TellyLogFab.bottomOffsetOf(context);
          return const SizedBox();
        }),
      ));
      expect(offset, 34 + TellyFloatingNavBar.height + 16);

      await tester.pumpWidget(Builder(builder: (context) {
        offset = TellyLogFab.bottomOffsetOf(context);
        return const SizedBox();
      }));
      expect(offset, 16 + TellyFloatingNavBar.height + 16);
    });
  });
}
