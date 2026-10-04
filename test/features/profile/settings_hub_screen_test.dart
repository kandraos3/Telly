import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/data/settings_services.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/canon_seed.dart';
import '../../helpers/router_harness.dart';

class FakeImageCache implements ImageCacheService {
  int bytes = 3 * 1024 * 1024;
  @override
  Future<int> sizeBytes() async => bytes;
  @override
  Future<void> clear() async => bytes = 0;
}

/// Records which export ran instead of writing files (dart:io never completes in fake async).
class RecordingExport extends CanonExportService {
  RecordingExport(RankingRepository rankings, this.calls)
      : super(rankings, ({required path, required mimeType, required subject}) async {});
  final List<String> calls;

  @override
  Future<int> exportCsv() async {
    calls.add('csv');
    return 0;
  }

  @override
  Future<int> exportLetterboxd() async {
    calls.add('letterboxd');
    return 0;
  }
}

void main() {
  late AppDatabase db;
  late FakeProfileRepository profiles;
  late FakeOnboardingRepository onboarding;
  late FakeImageCache cache;
  late List<String> shared;

  setUp(() {
    db = AppDatabase.inMemory();
    profiles = FakeProfileRepository();
    onboarding = FakeOnboardingRepository();
    cache = FakeImageCache();
    shared = [];
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(const SettingsHubScreen(), overrides: [
      databaseProvider.overrideWithValue(db),
      profileRepositoryProvider.overrideWithValue(profiles),
      onboardingRepositoryProvider.overrideWithValue(onboarding),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
      imageCacheServiceProvider.overrideWithValue(cache),
      canonExportServiceProvider.overrideWith((ref) => RecordingExport(RankingRepository(db), shared)),
    ]));
    await tester.pumpAndSettle();
  }

  group('FE-505 / FE-608: SCR-20 Settings', () {
    testWidgets('notification toggles persist to users.preferences with spec defaults', (tester) async {
      await pump(tester);
      final digest = find.byKey(const Key('settings_notify_weekly_digest'));
      expect(tester.widget<SwitchListTile>(find.descendant(of: digest, matching: find.byType(SwitchListTile))).value, isFalse, reason: 'spec S3 default OFF');
      await tester.tap(digest);
      await tester.pumpAndSettle();
      expect((profiles.preferences['notifications'] as Map)['weekly_digest'], isTrue);
      expect((profiles.preferences['notifications'] as Map)['friend_finale'], isTrue);
    });

    testWidgets('a failed save rolls the toggle back and says so', (tester) async {
      await pump(tester);
      profiles.failWrites = true;
      final quiet = find.byKey(const Key('settings_quiet_hours'));
      await tester.tap(quiet);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.descendant(of: quiet, matching: find.byType(SwitchListTile))).value, isFalse);
      expect(find.textContaining("Couldn't save that"), findsOneWidget);
    });

    testWidgets('subscription chips load and save the real selection', (tester) async {
      await onboarding.saveStreamingSetup(platformIds: {'netflix'}, includeFreePlatforms: false);
      await pump(tester);
      expect(tester.widget<FilterChip>(find.byKey(const Key('settings_sub_netflix'))).selected, isTrue);
      await tester.tap(find.byKey(const Key('settings_sub_crunchyroll')));
      await tester.pumpAndSettle();
      expect(onboarding.saves.last.$1, {'netflix', 'crunchyroll'});
    });

    testWidgets('clear cache empties the artwork cache', (tester) async {
      await pump(tester);
      expect(find.text('3.0 MB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_clear_cache')));
      await tester.pumpAndSettle();
      expect(find.text('0.0 MB'), findsOneWidget);
    });

    testWidgets('the export rows call the export service', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.byKey(const Key('settings_export_csv')));
      await tester.tap(find.byKey(const Key('settings_export_csv')));
      await tester.tap(find.byKey(const Key('settings_export_letterboxd')));
      await tester.pumpAndSettle();
      expect(shared, ['csv', 'letterboxd']);
    });
  });

  group('FE-608: CanonExportService', () {
    test('shares one CSV of both canons, each row tagged with its media_type', () async {
      await seedCanon(db, 'tv', ['Succession'], baseId: 76331);
      await seedCanon(db, 'movie', ['Heat'], baseId: 949);
      final files = <String>[];
      final service = CanonExportService(
        RankingRepository(db),
        ({required path, required mimeType, required subject}) async => files.add(File(path).readAsStringSync()),
        tempDir: () async => Directory.systemTemp,
      );
      expect(await service.exportCsv(), 2);
      expect(files.single, contains('media_type'));
      expect(files.single, contains('Heat,949,1,10.00'));
      expect(files.single, contains('Succession,76331,1,10.00'));

      expect(await service.exportLetterboxd(), 1, reason: 'films only');
    });
  });
}
