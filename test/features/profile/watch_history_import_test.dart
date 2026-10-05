import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/onboarding/data/canon_import_service.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/onboarding/domain/anilist_importer.dart';
import 'package:telly_app/features/onboarding/presentation/widgets/import_sources.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/data/settings_services.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

/// Finds one movie and one series per query, except queries containing "zzz".
class EchoTitleRepository implements TitleRepository {
  @override
  Future<TitleSearchOutcome> search(String query) async => query.contains('zzz')
      ? const TitleSearchOutcome([])
      : TitleSearchOutcome([
          TitleSearchResult(id: 1000 + query.hashCode.abs() % 100000, mediaType: 'movie', title: query),
          TitleSearchResult(id: 2000 + query.hashCode.abs() % 100000, mediaType: 'tv', title: query, isAnime: true),
        ]);

  @override
  Future<TitleCredits> fetchCredits(int id, String mediaType, {Duration? timeout}) async => TitleCredits.empty;
}

class FakeAniList extends AniListImporter {
  @override
  Future<List<AniListEntry>> fetchUserAnime(String username, {bool enableFranchiseRollup = false}) async {
    if (username != 'frieren_fan') throw AniListUserNotFoundException(username);
    return const [
      AniListEntry(id: 1, romajiTitle: 'Sousou no Frieren', englishTitle: 'Frieren', format: 'TV', userScore: 9.8),
      AniListEntry(id: 2, romajiTitle: 'Kimi no Na wa.', englishTitle: 'Your Name.', format: 'MOVIE', userScore: 9.0),
    ];
  }
}

class FakeImageCache implements ImageCacheService {
  @override
  Future<int> sizeBytes() async => 0;
  @override
  Future<void> clear() async {}
}

const csv = 'Date,Name,Year,Letterboxd URI,Rating\n'
    '2026-01-01,Heat,1995,https://boxd.it/a,5\n'
    '2026-01-02,Past Lives,2023,https://boxd.it/b,4.5\n'
    '2026-01-03,zzz Obscure Short,2001,https://boxd.it/c,3\n';

void main() {
  late AppDatabase db;
  late String? pickedCsv;

  setUp(() {
    db = AppDatabase.inMemory();
    pickedCsv = csv;
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(const SettingsHubScreen(), overrides: [
      databaseProvider.overrideWithValue(db),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
      imageCacheServiceProvider.overrideWithValue(FakeImageCache()),
      titleRepositoryProvider.overrideWithValue(EchoTitleRepository()),
      aniListImporterProvider.overrideWithValue(FakeAniList()),
      csvFilePickerProvider.overrideWithValue(() async => pickedCsv),
    ]));
    await tester.pumpAndSettle();
  }

  Future<void> tapImport(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('FE-SETTINGS-02: Settings → Import Watch History', () {
    testWidgets('lists both sources above the exports', (tester) async {
      await pump(tester);
      expect(find.text('IMPORT WATCH HISTORY'), findsOneWidget);
      expect(find.text('Import from Letterboxd'), findsOneWidget);
      expect(find.text('Import from AniList'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('IMPORT WATCH HISTORY')).dy,
        lessThan(tester.getTopLeft(find.text('DATA & EXPORTS')).dy),
      );
    });

    testWidgets('a Letterboxd CSV adds matched films to the movie canon and reports the rest', (tester) async {
      await pump(tester);
      await tapImport(tester, 'settings_import_letterboxd');

      expect(find.byKey(const Key('settings_import_summary')), findsOneWidget);
      expect(find.text("Added 2 titles from Letterboxd · 1 couldn't be matched"), findsOneWidget);
      final canon = await RankingRepository(db).getCanon('movie');
      expect(canon.map((r) => r.title), ['Heat', 'Past Lives'], reason: 'ordered by my rating');
      expect(await RankingRepository(db).getCanon('tv'), isEmpty, reason: 'dual canon');

      await tester.tap(find.byKey(const Key('settings_import_unmatched')));
      await tester.pumpAndSettle();
      expect(find.text('• zzz Obscure Short'), findsOneWidget);
    });

    testWidgets('importing the same file again adds nothing new', (tester) async {
      await pump(tester);
      await tapImport(tester, 'settings_import_letterboxd');
      await tapImport(tester, 'settings_import_letterboxd');

      expect(find.text("Added 0 titles from Letterboxd · 2 already in your canon · 1 couldn't be matched"), findsOneWidget);
      expect(await RankingRepository(db).getCanon('movie'), hasLength(2));
    });

    testWidgets('a file that is not a Letterboxd export says so', (tester) async {
      pickedCsv = 'foo,bar\n1,2\n';
      await pump(tester);
      await tapImport(tester, 'settings_import_letterboxd');
      expect(find.byKey(const Key('settings_import_error')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('settings_import_error'))).data, contains('watched.csv or ratings.csv'));
    });

    testWidgets('cancelling the file picker does nothing', (tester) async {
      pickedCsv = null;
      await pump(tester);
      await tapImport(tester, 'settings_import_letterboxd');
      expect(find.byKey(const Key('settings_import_summary')), findsNothing);
      expect(find.byKey(const Key('settings_import_error')), findsNothing);
    });

    testWidgets('an AniList username imports anime into both canons', (tester) async {
      await pump(tester);
      await tapImport(tester, 'settings_import_anilist');
      await tester.enterText(find.byKey(const Key('anilist_username_field')), 'frieren_fan');
      await tester.tap(find.byKey(const Key('anilist_import_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Added 2 titles from AniList'), findsOneWidget);
      expect((await RankingRepository(db).getCanon('tv')).single.title, 'Frieren');
      expect((await RankingRepository(db).getCanon('movie')).single.title, 'Your Name.');
    });

    testWidgets('an unknown AniList user is reported', (tester) async {
      await pump(tester);
      await tapImport(tester, 'settings_import_anilist');
      await tester.enterText(find.byKey(const Key('anilist_username_field')), 'nobody');
      await tester.tap(find.byKey(const Key('anilist_import_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('No AniList profile found for @nobody.'), findsOneWidget);
    });
  });

  test('FE-SETTINGS-02: ImportResult counts titles that were already ranked', () {
    const r = ImportResult(added: 2, matched: 5, unmatched: ['x']);
    expect(r.alreadyRanked, 3);
    expect(const ImportResult(added: 4).alreadyRanked, 0);
  });
}
