import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/controllers/graveyard_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/log_dropped_show_sheet.dart';

import '../../fakes/fake_graveyard_repository.dart';
import '../../helpers/canon_seed.dart';
import '../../helpers/router_harness.dart';

DroppedShow westworld({bool revisit = false}) => DroppedShow(
      id: 'drop-1',
      userId: 'u1',
      titleId: 63247,
      title: 'Westworld',
      releaseYear: 2016,
      droppedAtSeason: 3,
      droppedAtEpisode: 4,
      reason: DropReasonTaxonomy.jumpedShark,
      willingToRevisit: revisit,
      notes: 'Lost the mystery once they left the park.',
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  late AppDatabase db;
  late FakeGraveyardRepository repo;
  setUp(() {
    db = AppDatabase.inMemory();
    repo = FakeGraveyardRepository();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(const TvGraveyardScreen(), overrides: [
      graveyardRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
    ]));
    await tester.pumpAndSettle();
  }

  group('FE-307 / FE-608: SCR-18 TV Graveyard', () {
    testWidgets('renders persisted drops with milestone, reason and status', (tester) async {
      repo.shows.add(westworld());
      await pump(tester);
      expect(find.text('THE TV GRAVEYARD'), findsOneWidget);
      expect(find.text('WESTWORLD'), findsOneWidget);
      expect(find.text('2016 • Season 3, Episode 4'), findsOneWidget);
      expect(find.text('Reason: “Writing jumped the shark”'), findsOneWidget);
      expect(find.text('Dead & Buried'), findsOneWidget);
    });

    testWidgets('empty and error states; + opens the Logging Studio', (tester) async {
      await pump(tester);
      expect(find.text('WESTWORLD'), findsNothing);
      await tester.tap(find.byKey(const Key('graveyard_add_button')));
      await tester.pumpAndSettle();
      expect(find.text('route:/log'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      repo.failReads = true;
      await pump(tester);
      expect(find.byKey(const Key('graveyard_error')), findsOneWidget);
      repo
        ..failReads = false
        ..shows.add(westworld());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('WESTWORLD'), findsOneWidget);
    });

    testWidgets('LogDroppedShowSheet edits its form and emits DropDetails', (tester) async {
      DropDetails? saved;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: TellyTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LogDroppedShowSheet.show(context: context, titleId: 4607, title: 'Lost', releaseYear: 2004)
                    .then((d) => saved = d),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Lost (2004)'), findsOneWidget);
      expect(find.text('Season 1'), findsOneWidget, reason: 'neutral default, not a made-up S2E3');

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('Season 2'), findsOneWidget);
      await tester.tap(find.text('Pacing slowed down / Boring'));
      await tester.ensureVisible(find.text('🔄 Willing to Revisit'));
      await tester.tap(find.text('🔄 Willing to Revisit'));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Too many filler episodes.');
      await tester.ensureVisible(find.text('🪦 Bury in The TV Graveyard'));
      await tester.tap(find.text('🪦 Bury in The TV Graveyard'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.season, 2);
      expect(saved!.reason, DropReasonTaxonomy.pacingSlowed);
      expect(saved!.willingToRevisit, isTrue);
      expect(saved!.notes, 'Too many filler episodes.');
    });
  });

  group('FE-608: GraveyardController', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        graveyardRepositoryProvider.overrideWithValue(repo),
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('dropping a ranked show removes it from the canon without corrupting ranks', () async {
      await seedCanon(db, 'tv', ['A', 'B', 'C', 'D'], baseId: 1);
      final c = container();
      await c.read(graveyardControllerProvider.future);
      await c.read(graveyardControllerProvider.notifier).drop(titleId: 2, mediaType: 'tv', details: const DropDetails());

      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.map((r) => (r.showId, r.rankPosition)), [(1, 1), (3, 2), (4, 3)]);
      expect((await db.pendingMutationDao.getAllFifo()).single.kind, MutationKind.delete);
      expect(c.read(graveyardControllerProvider).value!.single.titleId, 2);
    });

    test('dropping an unranked show leaves the canon alone', () async {
      await seedCanon(db, 'tv', ['A'], baseId: 1);
      final c = container();
      await c.read(graveyardControllerProvider.future);
      await c.read(graveyardControllerProvider.notifier).drop(titleId: 99, mediaType: 'tv', details: const DropDetails());
      expect(await db.localRankingDao.getRankingsByCanon('tv'), hasLength(1));
      expect(await db.pendingMutationDao.count(), 0);
    });

    test('a rejected flag update rolls back', () async {
      repo.shows.add(westworld());
      final c = container();
      await c.read(graveyardControllerProvider.future);
      repo.failWrites = true;
      await expectLater(
        c.read(graveyardControllerProvider.notifier).setFlags(westworld(), willingToRevisit: true),
        throwsException,
      );
      expect(c.read(graveyardControllerProvider).value!.single.willingToRevisit, isFalse);
    });
  });

  group('FE-608: SupabaseGraveyardRepository', () {
    test('drop upserts the enum reason and maps the joined row back', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode({
              'id': 'd1',
              'user_id': 'u1',
              'title_id': 63247,
              'media_type': 'tv',
              'dropped_at_season': 3,
              'dropped_at_episode': 4,
              'reason': 'WRITING_JUMPED_SHARK',
              'willing_to_revisit': false,
              'notify_on_acclaim': true,
              'notes': null,
              'created_at': '2026-10-03T10:00:00+00:00',
              'titles': {'title': 'Westworld', 'poster_path': '/w.jpg', 'release_date': '2016-10-02'},
            }),
            201,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final show = await SupabaseGraveyardRepository(client, currentUserId: () => 'u1').drop(
        titleId: 63247,
        mediaType: 'tv',
        details: const DropDetails(season: 3, episode: 4, notifyOnAcclaim: true),
      );

      expect(requests.single.url.path, '/rest/v1/user_dropped_shows');
      expect(requests.single.url.queryParameters['on_conflict'], 'user_id,title_id,media_type');
      expect(jsonDecode(requests.single.body), containsPair('reason', 'WRITING_JUMPED_SHARK'));
      expect(show.title, 'Westworld');
      expect(show.releaseYear, 2016);
      expect(show.reason, DropReasonTaxonomy.jumpedShark);
      expect(show.posterUrl, 'https://image.tmdb.org/t/p/w342/w.jpg');
    });
  });
}
