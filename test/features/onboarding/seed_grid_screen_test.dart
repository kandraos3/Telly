import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/onboarding/data/canon_import_service.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/onboarding/domain/anilist_importer.dart';
import 'package:telly_app/features/onboarding/presentation/screens/seed_grid_screen.dart';

import '../../helpers/router_harness.dart';

/// Every query matches exactly one title of each media type, with a stable id.
class EchoTitleRepository implements TitleRepository {
  @override
  Future<TitleSearchOutcome> search(String query) async => TitleSearchOutcome([
        TitleSearchResult(id: 1000 + query.hashCode.abs() % 100000, mediaType: 'movie', title: query),
        TitleSearchResult(id: 2000 + query.hashCode.abs() % 100000, mediaType: 'tv', title: query, isAnime: true),
      ]);

  @override
  Future<TitleCredits> fetchCredits(int id, String mediaType) async => TitleCredits.empty;
}

class FakeAniList extends AniListImporter {
  @override
  Future<List<AniListEntry>> fetchUserAnime(String username, {bool enableFranchiseRollup = false}) async => const [
        AniListEntry(id: 1, romajiTitle: 'Sousou no Frieren', englishTitle: 'Frieren', format: 'TV', userScore: 9.8),
        AniListEntry(id: 2, romajiTitle: 'Kimi no Na wa.', englishTitle: 'Your Name.', format: 'MOVIE', userScore: 9.0),
      ];
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {String? csv}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(const SeedGridScreen(), overrides: [
      databaseProvider.overrideWithValue(db),
      posterNetworkImagesProvider.overrideWithValue(false),
      titleRepositoryProvider.overrideWithValue(EchoTitleRepository()),
      aniListImporterProvider.overrideWithValue(FakeAniList()),
      csvFilePickerProvider.overrideWithValue(() async => csv),
    ]));
    await tester.pumpAndSettle();
  }

  TellyPrimaryButton cta(WidgetTester tester) =>
      tester.widget<TellyPrimaryButton>(find.byKey(const Key('start_duels_button')));

  int countOf(bool Function(SeedTitle) test) => kTop50SeedTitles.where(test).length;

  group('SCR-03 SeedGridScreen (FE-109, FE-606)', () {
    test('poster paths resolve to TMDB image URLs', () {
      expect(TmdbImages.poster('/abc.jpg'), 'https://image.tmdb.org/t/p/w342/abc.jpg');
      expect(TmdbImages.poster('https://cdn.example/x.jpg'), 'https://cdn.example/x.jpg');
      expect(TmdbImages.poster(null), isNull);
    });


    testWidgets('renders headers, importers and filter chips with live counts', (tester) async {
      await pump(tester);
      expect(find.text("Tap movies, series & anime you've watched."), findsOneWidget);
      expect(find.text('Import from Letterboxd'), findsOneWidget);
      expect(find.text('Import from AniList / MyAnimeList'), findsOneWidget);
      expect(find.text('All (${kTop50SeedTitles.length})'), findsOneWidget);
      expect(find.text('🎬 Movies (${countOf((t) => t.mediaType == 'movie')})'), findsOneWidget);
      expect(find.text('📺 Series (${countOf((t) => t.mediaType == 'tv' && !t.isAnime)})'), findsOneWidget);
      expect(find.text('⚡ Anime (${countOf((t) => t.isAnime)})'), findsOneWidget);
      expect(find.text('Select at least 8 titles (0/8 selected)'), findsOneWidget);
      expect(cta(tester).onPressed, isNull);
    });

    testWidgets('filter pills narrow the grid', (tester) async {
      await pump(tester);
      await tester.tap(find.textContaining('🎬 Movies'));
      await tester.pumpAndSettle();
      expect(find.text('Interstellar'), findsOneWidget);
      expect(find.text('Succession'), findsNothing);

      await tester.ensureVisible(find.textContaining('⚡ Anime'));
      await tester.tap(find.textContaining('⚡ Anime'));
      await tester.pumpAndSettle();
      expect(find.text('Attack on Titan'), findsOneWidget);
      expect(find.text('Interstellar'), findsNothing);
    });

    testWidgets('CTA unlocks at 8 picks and starts the tournament', (tester) async {
      await pump(tester);
      final picks = kTop50SeedTitles.take(8).toList();
      for (final (i, s) in picks.indexed) {
        final card = find.byKey(ValueKey('seed_card_${s.mediaType}_${s.id}'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        if (i < 7) expect(find.text('Select at least 8 titles (${i + 1}/8 selected)'), findsOneWidget);
      }
      expect(find.text('Start Ranking Duels →'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_duels_button')));
      await tester.pumpAndSettle();
      expect(find.text('route:/onboarding/tournament'), findsOneWidget);
    });

    testWidgets('Letterboxd import persists the CSV as a movie canon and unlocks the CTA', (tester) async {
      await pump(tester, csv: [
        'Date,Name,Year,Letterboxd URI,Rating',
        '2024-01-01,Heat,1995,https://boxd.it/a,4',
        '2024-01-02,Oppenheimer,2023,https://boxd.it/b,5',
        '2024-01-03,Cats,2019,https://boxd.it/c,0.5',
      ].join('\n'));
      await tester.tap(find.byKey(const Key('import_letterboxd')));
      await tester.pumpAndSettle();

      expect(find.text('Imported 3 titles'), findsOneWidget);
      expect(find.byKey(const Key('imported_count_text')), findsOneWidget);
      expect(cta(tester).onPressed, isNotNull);
      final canon = await db.localRankingDao.getRankingsByCanon('movie');
      expect(canon.map((r) => r.title), ['Oppenheimer', 'Heat', 'Cats'], reason: 'ordered by star rating');
    });

    testWidgets('AniList import asks for a username and splits movies from series', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('import_anilist')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('anilist_username_field')), 'frieren_fan');
      await tester.tap(find.byKey(const Key('anilist_import_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Imported 2 titles'), findsOneWidget);
      expect((await db.localRankingDao.getRankingsByCanon('tv')).map((r) => r.title), ['Frieren']);
      expect((await db.localRankingDao.getRankingsByCanon('movie')).map((r) => r.title), ['Your Name.']);
    });
  });
}
