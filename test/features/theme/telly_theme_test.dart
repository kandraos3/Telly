import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/settings_controllers.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = _luminance(foreground);
  final l2 = _luminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('FE-THEME-01: Day Cathode Color Tokens & WCAG Contrast Tests', () {
    test('Day Cathode text tokens pass WCAG AAA / AA contrast requirements', () {
      const canvas = TellyColors.lightBackgroundPrimary; // #F6F7F9
      const card = TellyColors.lightBackgroundSurface; // #FFFFFF

      // Text Primary: AAA >= 7.0:1
      final primaryOnCanvas = _contrastRatio(TellyColors.lightTextPrimary, canvas);
      expect(primaryOnCanvas, greaterThanOrEqualTo(7.0),
          reason: 'Primary text must pass WCAG AAA (>= 7:1) on day canvas');

      final primaryOnCard = _contrastRatio(TellyColors.lightTextPrimary, card);
      expect(primaryOnCard, greaterThanOrEqualTo(7.0),
          reason: 'Primary text must pass WCAG AAA (>= 7:1) on day card');

      // Text Secondary: AAA >= 7.0:1 on card
      final secondaryOnCard = _contrastRatio(TellyColors.lightTextSecondary, card);
      expect(secondaryOnCard, greaterThanOrEqualTo(7.0),
          reason: 'Secondary text must pass WCAG AAA (>= 7:1) on day card');

      // Text Tertiary: AA >= 4.5:1 on card
      final tertiaryOnCard = _contrastRatio(TellyColors.lightTextTertiary, card);
      expect(tertiaryOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Tertiary text must pass WCAG AA (>= 4.5:1) on day card');
    });

    test('Day Cathode brand accent tokens pass WCAG AA contrast requirements', () {
      const card = TellyColors.lightBackgroundSurface; // #FFFFFF

      // Lime on light >= 4.5:1
      final limeOnCard = _contrastRatio(TellyColors.lightPhosphorLime, card);
      expect(limeOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Phosphor Lime on light card must pass WCAG AA (>= 4.5:1)');

      // Coral on light >= 4.5:1
      final coralOnCard = _contrastRatio(TellyColors.lightNeonCoral, card);
      expect(coralOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Neon Coral on light card must pass WCAG AA (>= 4.5:1)');

      // Amber on light >= 4.5:1
      final amberOnCard = _contrastRatio(TellyColors.lightWarmAmber, card);
      expect(amberOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Warm Amber on light card must pass WCAG AA (>= 4.5:1)');

      // Violet on light >= 4.5:1
      final violetOnCard = _contrastRatio(TellyColors.lightElectricViolet, card);
      expect(violetOnCard, greaterThanOrEqualTo(4.5),
          reason: 'Electric Violet on light card must pass WCAG AA (>= 4.5:1)');
    });

    test('TellyTheme.light configures light brightness and correct surface colors', () {
      final light = TellyTheme.light;
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, TellyColors.lightBackgroundPrimary);
      expect(light.cardColor, TellyColors.lightBackgroundSurface);
      expect(light.colorScheme.primary, TellyColors.lightPhosphorLime);
      expect(light.colorScheme.surface, TellyColors.lightBackgroundSurface);
      expect(light.dividerColor, TellyColors.lightStrokeSubtle);
    });

    test('TellyTheme.dark configures dark brightness and void surface colors', () {
      final dark = TellyTheme.dark;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, TellyColors.backgroundPrimary);
      expect(dark.cardColor, TellyColors.backgroundSurface);
      expect(dark.colorScheme.primary, TellyColors.phosphorLime);
    });
  });

  group('FE-THEME-01: AppPreferences Theme Mode Serialization Tests', () {
    test('serializes and deserializes theme_mode correctly', () {
      const defaultPrefs = AppPreferences();
      expect(defaultPrefs.themeMode, TellyThemeMode.dark);

      final json = defaultPrefs.toJson();
      expect(json['theme_mode'], 'dark');

      final fromJson = AppPreferences.fromJson(json);
      expect(fromJson.themeMode, TellyThemeMode.dark);

      final lightPrefs = defaultPrefs.copyWith(themeMode: TellyThemeMode.light);
      expect(lightPrefs.themeMode, TellyThemeMode.light);
      final lightJson = lightPrefs.toJson();
      expect(lightJson['theme_mode'], 'light');

      final fromLightJson = AppPreferences.fromJson(lightJson);
      expect(fromLightJson.themeMode, TellyThemeMode.light);

      final systemPrefs = defaultPrefs.copyWith(themeMode: TellyThemeMode.system);
      expect(systemPrefs.themeMode, TellyThemeMode.system);
      expect(systemPrefs.toJson()['theme_mode'], 'system');
    });
  });

  group('FE-THEME-01: SettingsHubScreen Theme Switcher Widget Tests', () {
    late FakeProfileRepository profiles;

    setUp(() {
      profiles = FakeProfileRepository();
    });

    testWidgets('renders Theme Mode selector and switches to Light mode', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        routerHarness(
          const SettingsHubScreen(),
          overrides: [
            profileRepositoryProvider.overrideWithValue(profiles),
            onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify Appearance & Theme section exists
      expect(find.text('APPEARANCE & THEME'), findsOneWidget);
      expect(find.text('Color Theme'), findsOneWidget);
      expect(find.byKey(const Key('settings_theme_mode')), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);

      // Tap "Light" segment
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      // Verify persisted preferences in profile repository
      final savedPrefs = await profiles.fetchPreferences();
      expect(savedPrefs['theme_mode'], 'light');
    });

    testWidgets('switches to System preference and persists', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        routerHarness(
          const SettingsHubScreen(),
          overrides: [
            profileRepositoryProvider.overrideWithValue(profiles),
            onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap "System" segment
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      // Verify persisted preferences in profile repository
      final savedPrefs = await profiles.fetchPreferences();
      expect(savedPrefs['theme_mode'], 'system');
    });
  });
}
