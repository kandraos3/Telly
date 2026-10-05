import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/squads/data/squad_repository.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';
import 'package:telly_app/features/squads/presentation/screens/squad_hub_screen.dart';
import 'package:telly_app/features/squads/presentation/screens/squads_list_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

SquadMember member(String id, String name, {SquadRole role = SquadRole.member}) =>
    SquadMember(userId: id, username: name.toLowerCase(), displayName: name, role: role, joinedAt: DateTime(2026));

SquadConsensusItem item(int rank, int id, String title, {int champ = 1, int low = 3}) => SquadConsensusItem(
      consensusRank: rank,
      titleId: id,
      title: title,
      releaseYear: 0,
      totalBordaPoints: 100 - rank,
      championUserId: 'u1',
      championDisplayName: 'Jordan',
      championRank: champ,
      lowestUserId: 'u3',
      lowestDisplayName: 'Alex',
      lowestRank: low,
      membersRankedCount: 3,
      rankVariance: (low - champ).toDouble(),
    );

class FakeSquadRepository implements SquadRepository {
  final squads = <String, Squad>{};
  final boards = <String, List<SquadConsensusItem>>{};
  List<SharedWatchlistItem> watchlist = const [];
  final consensusCalls = <String>[];
  final added = <(String, String)>[];
  final deleted = <String>[];
  final left = <String>[];
  bool failReads = false;
  bool failWrites = false;

  /// Lookup table for [findInvitee], keyed by lower-case handle or email.
  final invitees = <String, SquadInvitee>{};
  final lookups = <String>[];

  @override
  Future<List<Squad>> mySquads() async {
    if (failReads) throw Exception('offline');
    return squads.values.toList();
  }

  @override
  Future<Squad> fetchSquad(String squadId) async {
    if (failReads) throw Exception('offline');
    return squads[squadId]!;
  }

  @override
  Future<List<SquadConsensusItem>> consensus(Squad squad, String mediaType) async {
    consensusCalls.add(mediaType);
    return boards[mediaType] ?? const [];
  }

  @override
  Future<List<SharedWatchlistItem>> sharedWatchlist(String squadId) async => watchlist;

  @override
  Future<Squad> create({required String name, String? description}) async {
    final s = Squad(id: 'sq-new', name: name, createdBy: 'u1', members: [member('u1', 'Jordan', role: SquadRole.owner)], createdAt: DateTime(2026));
    return squads[s.id] = s;
  }

  @override
  Future<SquadInvitee?> findInvitee(String query) async {
    lookups.add(query);
    return invitees[query.trim().toLowerCase().replaceFirst(RegExp('^@'), '')];
  }

  @override
  Future<void> addMember({required String squadId, required String userId}) async {
    added.add((squadId, userId));
    final s = squads[squadId]!;
    squads[squadId] = Squad(
      id: s.id,
      name: s.name,
      createdBy: s.createdBy,
      members: [...s.members, member(userId, 'Maya')],
      createdAt: s.createdAt,
    );
  }
  @override
  Future<void> deleteSquad(String squadId) async {
    if (failWrites) throw Exception('rejected');
    deleted.add(squadId);
    squads.remove(squadId);
  }

  @override
  Future<void> leaveSquad(String squadId) async {
    if (failWrites) throw Exception('rejected');
    left.add(squadId);
    squads.remove(squadId);
  }
}

void main() {
  late FakeSquadRepository repo;
  late FakeProfileRepository profiles;

  setUp(() {
    repo = FakeSquadRepository();
    profiles = FakeProfileRepository();
    repo.squads['sq-1'] = Squad(
      id: 'sq-1',
      name: 'The Apartment',
      createdBy: 'u1',
      members: [member('u1', 'Jordan', role: SquadRole.owner), member('u3', 'Alex')],
      createdAt: DateTime(2026),
    );
    repo.boards['tv'] = [item(1, 101, 'Succession'), item(2, 105, 'Lost', champ: 4, low: 68)];
    repo.boards['movie'] = [item(1, 201, 'Heat')];
  });

  Future<void> pump(WidgetTester tester, Widget screen, {String me = 'u1'}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(screen, overrides: [
      squadRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(profiles),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: me)),
    ]));
    await tester.pumpAndSettle();
  }

  group('FE-306 / FE-608: SCR-17 SquadHubScreen', () {
    testWidgets('renders members, the Borda leaderboard and the biggest debate', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_canon_tv')));
      await tester.pumpAndSettle();
      // FE-HEADER-02: the name as typed, the member count on a quiet second line.
      expect(tester.widget<Text>(find.byKey(const Key('subpage_title'))).data, 'The Apartment');
      expect(tester.widget<Text>(find.byKey(const Key('subpage_subtitle'))).data, '2 members');
      // FE-SQUADS-04: the hero names the members; the debate card is titled as typed.
      expect(tester.widget<Text>(find.byKey(const Key('squad_members_line'))).data, 'Jordan and Alex');
      expect(find.byKey(const Key('squad_consensus_101')), findsOneWidget);
      final debate = find.byKey(const Key('squad_debate_105'));
      expect(find.descendant(of: debate, matching: find.text('BIGGEST DEBATE')), findsOneWidget);
      expect(find.descendant(of: debate, matching: find.text('Lost')), findsOneWidget);
      expect(find.descendant(of: debate, matching: find.text('64')), findsOneWidget);
      expect(find.descendant(of: debate, matching: find.text('ranks apart')), findsOneWidget);
    });

    testWidgets('switching canon loads that canon once', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_canon_tv')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('squad_consensus_101')), findsOneWidget);
      await tester.tap(find.byKey(const Key('squad_canon_movie')));
      await tester.tap(find.byKey(const Key('squad_canon_tv')));
      await tester.pumpAndSettle();
      expect(repo.consensusCalls, ['movie', 'tv']);
    });

    testWidgets('FE-SQUADS-02: opens on Movies, with Movies left of TV Shows', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      expect(find.byKey(const Key('squad_consensus_201')), findsOneWidget);
      expect(repo.consensusCalls, ['movie']);
      expect(
        tester.getCenter(find.byKey(const Key('squad_canon_movie'))).dx,
        lessThan(tester.getCenter(find.byKey(const Key('squad_canon_tv'))).dx),
      );
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('TV Shows'), findsOneWidget);
    });

    testWidgets('Squad Watchlist and Debates tabs show their own content', (tester) async {
      repo.watchlist = const [
        SharedWatchlistItem(titleId: 1396, mediaType: 'tv', title: 'Breaking Bad', queuedBy: 2, memberCount: 2),
      ];
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_tab_watchlist')));
      await tester.pumpAndSettle();
      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('Everyone wants to watch'), findsOneWidget);
      expect(find.byKey(const Key('squad_consensus_101')), findsNothing);

      await tester.tap(find.byKey(const Key('squad_tab_debates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('squad_canon_tv')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('squad_debate_105')), findsOneWidget);
      expect(find.byKey(const Key('squad_debate_101')), findsNothing);
    });

    Future<void> openInvite(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const Key('squad_invite_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('squad_invite_field')), text);
      await tester.pumpAndSettle();
    }

    bool addEnabled(WidgetTester tester) =>
        tester.widget<TextButton>(find.byKey(const Key('squad_invite_confirm'))).onPressed != null;

    testWidgets('the owner invites by handle once it validates', (tester) async {
      repo.invitees['maya'] = const SquadInvitee(userId: 'u2', username: 'maya', displayName: 'Maya Lin');
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await openInvite(tester, '@maya');
      expect(find.byKey(const Key('squad_invite_valid')), findsOneWidget);
      expect(find.text('Maya Lin · @maya'), findsOneWidget);
      expect(addEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('squad_invite_confirm')));
      await tester.pumpAndSettle();
      expect(repo.added.single, ('sq-1', 'u2'));
      expect(tester.widget<Text>(find.byKey(const Key('squad_members_line'))).data, 'Jordan, Alex and Maya');
      expect(find.text('Added @maya'), findsOneWidget);
    });

    testWidgets('FE-SQUADS-02: the owner invites by email', (tester) async {
      repo.invitees['maya@example.com'] =
          const SquadInvitee(userId: 'u2', username: 'maya', displayName: 'Maya Lin', matchedByEmail: true);
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await openInvite(tester, 'Maya@Example.com');
      expect(find.byKey(const Key('squad_invite_valid')), findsOneWidget);
      await tester.tap(find.byKey(const Key('squad_invite_confirm')));
      await tester.pumpAndSettle();
      expect(repo.added.single, ('sq-1', 'u2'));
    });

    testWidgets('FE-SQUADS-02: unknown, malformed and existing members are flagged live', (tester) async {
      repo.invitees['alex'] = const SquadInvitee(userId: 'u3', username: 'alex', displayName: 'Alex');
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));

      await openInvite(tester, 'nobody_here');
      expect(find.byKey(const Key('squad_invite_invalid')), findsOneWidget);
      expect(find.text('No one found with @nobody_here.'), findsOneWidget);
      expect(addEnabled(tester), isFalse);

      await tester.enterText(find.byKey(const Key('squad_invite_field')), 'ghost@nowhere.dev');
      await tester.pumpAndSettle();
      expect(find.text('No Telly account uses that email.'), findsOneWidget);

      final lookupsBefore = repo.lookups.length;
      await tester.enterText(find.byKey(const Key('squad_invite_field')), 'maya@');
      await tester.pumpAndSettle();
      expect(find.text('Enter a full email address.'), findsOneWidget);
      expect(repo.lookups.length, lookupsBefore, reason: 'malformed input never hits the server');

      await tester.enterText(find.byKey(const Key('squad_invite_field')), 'alex');
      await tester.pumpAndSettle();
      expect(find.text('@alex is already in this squad.'), findsOneWidget);
      expect(addEnabled(tester), isFalse);
    });

    testWidgets('FE-SQUADS-02: typing quickly checks only the settled text', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_invite_button')));
      await tester.pumpAndSettle();
      for (final partial in ['may', 'maya', 'maya_']) {
        await tester.enterText(find.byKey(const Key('squad_invite_field')), partial);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(repo.lookups, ['maya_']);
    });

    testWidgets('members cannot invite', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'), me: 'u3');
      expect(find.byKey(const Key('squad_invite_button')), findsNothing);
    });

    testWidgets('a failed load shows a retryable error', (tester) async {
      repo.failReads = true;
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      expect(find.byKey(const Key('squad_error')), findsOneWidget);
    });
  });

  group('FE-SQUADS-04: squad hub redesign', () {
    setUp(() {
      repo.boards['movie'] = [
        for (final (rank, id, title) in [(1, 201, 'Heat'), (2, 202, 'Alien'), (3, 203, 'Ran'), (4, 204, 'Jaws'), (5, 205, 'Up')])
          item(rank, id, title),
      ];
    });

    testWidgets('top three sit on the podium, the rest in ranked rows with who ranked them', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      expect(find.text('SQUAD TOP 3'), findsOneWidget);
      expect(find.text('THE RANKING'), findsOneWidget);
      expect(find.text('5 titles'), findsOneWidget);
      for (final id in [201, 202, 203, 204, 205]) {
        expect(find.byKey(Key('squad_consensus_$id')), findsOneWidget);
      }
      final row4 = find.byKey(const Key('squad_consensus_204'));
      expect(find.descendant(of: row4, matching: find.text('#4')), findsOneWidget);
      expect(find.descendant(of: row4, matching: find.text('Jordan #1')), findsOneWidget);
      expect(find.descendant(of: row4, matching: find.text('Alex #3')), findsOneWidget);
      expect(find.descendant(of: row4, matching: find.text('Ranked by 3 of 2')), findsOneWidget);
      // Podium cards are posters, not rows: no champion / lowest line.
      expect(find.descendant(of: find.byKey(const Key('squad_consensus_201')), matching: find.byKey(const Key('squad_row_lowest'))), findsNothing);
    });

    testWidgets('consensus titles open their title page', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_consensus_204')));
      await tester.pumpAndSettle();
      expect(find.text('route:/title/tv/204'), findsOneWidget, reason: 'the fixture items are tagged tv');
    });

    testWidgets('hero stats follow the canon shown', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      String stat(String key) =>
          tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first).data!;
      expect(stat('squad_stat_members'), '2');
      expect(stat('squad_stat_titles'), '5');
      expect(stat('squad_stat_debates'), '0');

      await tester.tap(find.byKey(const Key('squad_canon_tv')));
      await tester.pumpAndSettle();
      expect(stat('squad_stat_titles'), '2');
      expect(stat('squad_stat_debates'), '1');
    });

    testWidgets('the members row opens the member list, which opens profiles', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_members_button')));
      await tester.pumpAndSettle();
      expect(find.text('Members (2)'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('squad_member_u1')), matching: find.text('OWNER')), findsOneWidget);
      expect(find.text('@alex'), findsOneWidget);

      await tester.tap(find.byKey(const Key('squad_member_u3')));
      await tester.pumpAndSettle();
      expect(find.text('route:/u/alex'), findsOneWidget);
    });

    testWidgets('an empty canon offers to rank a title', (tester) async {
      repo.boards['movie'] = [];
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      expect(find.byKey(const Key('squad_consensus_empty')), findsOneWidget);
      expect(find.textContaining('Once members rank a movie'), findsOneWidget);
      await tester.tap(find.text('Rank a title'));
      await tester.pumpAndSettle();
      expect(find.text('route:/log'), findsOneWidget);
    });

    testWidgets('watchlist cards show how many members want each title', (tester) async {
      repo.watchlist = const [
        SharedWatchlistItem(titleId: 1396, mediaType: 'tv', title: 'Breaking Bad', queuedBy: 2, memberCount: 2),
        SharedWatchlistItem(titleId: 680, mediaType: 'movie', title: 'Pulp Fiction', queuedBy: 2, memberCount: 3),
      ];
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_tab_watchlist')));
      await tester.pumpAndSettle();

      expect(find.text('WANT TO WATCH (2)'), findsOneWidget);
      expect(find.byKey(const Key('squad_canon_movie')), findsNothing, reason: 'the watchlist spans both canons');
      final everyone = find.byKey(const Key('squad_watch_tv_1396'));
      expect(find.descendant(of: everyone, matching: find.text('EVERYONE')), findsOneWidget);
      final some = find.byKey(const Key('squad_watch_movie_680'));
      expect(find.descendant(of: some, matching: find.text('2 of 3 want to watch')), findsOneWidget);
      expect(find.descendant(of: some, matching: find.text('EVERYONE')), findsNothing);
      expect(
        tester.widget<LinearProgressIndicator>(find.descendant(of: some, matching: find.byType(LinearProgressIndicator))).value,
        closeTo(2 / 3, 1e-9),
      );

      await tester.tap(some);
      await tester.pumpAndSettle();
      expect(find.text('route:/title/movie/680'), findsOneWidget);
    });

    testWidgets('empty watchlist and debates use the shared empty state', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await tester.tap(find.byKey(const Key('squad_tab_watchlist')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('squad_watchlist_empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('squad_tab_debates')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('squad_debates_empty')), findsOneWidget, reason: 'no hot debates among the movies');
    });
  });

  group('FE-SQUADS-01: delete and leave squad', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('squad_menu_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('the owner sees Delete Squad, confirms, and returns to the squads list', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await openMenu(tester);
      expect(find.byKey(const Key('squad_leave')), findsNothing);
      await tester.tap(find.byKey(const Key('squad_delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete The Apartment?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('squad_destructive_confirm')));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['sq-1']);
      expect(repo.left, isEmpty);
      expect(find.text('route:/squads'), findsOneWidget);
    });

    testWidgets('a member sees Leave Squad and leaves after confirming', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'), me: 'u3');
      await openMenu(tester);
      expect(find.byKey(const Key('squad_delete')), findsNothing);
      await tester.tap(find.byKey(const Key('squad_leave')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('squad_destructive_confirm')));
      await tester.pumpAndSettle();

      expect(repo.left, ['sq-1']);
      expect(repo.deleted, isEmpty);
      expect(find.text('route:/squads'), findsOneWidget);
    });

    testWidgets('cancelling keeps the squad', (tester) async {
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('squad_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('squad_destructive_cancel')));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(tester.widget<Text>(find.byKey(const Key('subpage_title'))).data, 'The Apartment');
    });

    testWidgets('a rejected delete stays on the hub and says so', (tester) async {
      repo.failWrites = true;
      await pump(tester, const SquadHubScreen(squadId: 'sq-1'));
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('squad_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('squad_destructive_confirm')));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't delete the squad. Try again."), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('subpage_title'))).data, 'The Apartment');
    });
  });

  group('FE-608: SquadsListScreen', () {
    testWidgets('lists my squads and creates a new one', (tester) async {
      await pump(tester, const SquadsListScreen());
      expect(find.text('The Apartment'), findsOneWidget);
      await tester.tap(find.byKey(const Key('squad_row_sq-1')));
      await tester.pumpAndSettle();
      expect(find.text('route:/squads/sq-1'), findsOneWidget);
    });

    testWidgets('create opens the new squad', (tester) async {
      await pump(tester, const SquadsListScreen());
      await tester.tap(find.byKey(const Key('create_squad_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('squad_name_field')), 'Sci-Fi Club');
      await tester.pump(); // Create enables once a name is typed (FE-SQUADS-03).
      await tester.tap(find.byKey(const Key('squad_create_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('route:/squads/sq-new'), findsOneWidget);
    });
  });

  group('FE-SQUADS-03: My Squads redesign', () {
    setUp(() {
      repo.squads['sq-2'] = Squad(
        id: 'sq-2',
        name: 'Sci-Fi Book Club',
        description: 'Dune twice a year',
        createdBy: 'u9',
        members: [member('u9', 'Maya', role: SquadRole.owner), member('u1', 'Jordan', role: SquadRole.admin)],
        memberTotal: 7,
        myRole: SquadRole.admin,
        createdAt: DateTime(2026, 2),
      );
    });

    testWidgets('cards show the monogram, role, description, member faces and the full count', (tester) async {
      repo.squads['sq-1'] = Squad(
        id: 'sq-1',
        name: 'The Apartment',
        createdBy: 'u1',
        members: [member('u1', 'Jordan', role: SquadRole.owner), member('u3', 'Alex')],
        myRole: SquadRole.owner,
        createdAt: DateTime(2026),
      );
      await pump(tester, const SquadsListScreen());

      expect(find.text('MY SQUADS (2)'), findsOneWidget);
      expect(find.text('TA'), findsOneWidget, reason: 'monogram from the last two words');
      expect(find.text('BC'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Dune twice a year'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('squad_member_count_sq-2'))).data, '7 members');
      expect(tester.widget<Text>(find.byKey(const Key('squad_member_count_sq-1'))).data, '2 members');
      // Two previews of seven: two faces, then +5.
      expect(find.text('+5'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing, reason: 'create lives in the header, as on Queue');
    });

    testWidgets('no squads shows the empty state, whose button opens the create sheet', (tester) async {
      repo.squads.clear();
      await pump(tester, const SquadsListScreen());
      expect(find.byKey(const Key('squads_empty')), findsOneWidget);
      expect(find.text('No squads yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('create_squad_empty_button')));
      await tester.pumpAndSettle();
      expect(find.text('New squad'), findsOneWidget);
      VoidCallback? createAction() =>
          tester.widget<InkWell>(find.descendant(of: find.byKey(const Key('squad_create_confirm')), matching: find.byType(InkWell))).onTap;
      expect(createAction(), isNull, reason: 'a blank name cannot be created');

      await tester.enterText(find.byKey(const Key('squad_name_field')), '   ');
      await tester.pump();
      expect(createAction(), isNull);

      await tester.enterText(find.byKey(const Key('squad_name_field')), 'Roomies');
      await tester.pump();
      expect(createAction(), isNotNull);
      await tester.tap(find.byKey(const Key('squad_create_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('route:/squads/sq-new'), findsOneWidget);
    });

    testWidgets('a failed load offers Retry, which reloads the list', (tester) async {
      repo.failReads = true;
      await pump(tester, const SquadsListScreen());
      expect(find.byKey(const Key('squads_error')), findsOneWidget);

      repo.failReads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('squad_row_sq-1')), findsOneWidget);
    });

    test('monogram initials come from the last two words', () {
      expect(SquadMonogram.initials('The Apartment'), 'TA');
      expect(SquadMonogram.initials('Sci-Fi Book Club'), 'BC');
      expect(SquadMonogram.initials('  roomies '), 'R');
      expect(SquadMonogram.initials(''), '?');
    });
  });

  group('FE-608: SupabaseSquadRepository', () {
    test('consensus maps champion/lowest names from members and calls the RPC per canon', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode([
              {
                'consensus_rank': 1,
                'title_id': 1396,
                'title': 'Breaking Bad',
                'poster_path': '/bb.jpg',
                'total_borda_points': 9,
                'champion_user_id': 'u1',
                'champion_rank': 1,
                'lowest_user_id': 'u3',
                'lowest_rank': 4,
                'members_ranked_count': 2,
                'rank_variance': 4.5,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final board = await SupabaseSquadRepository(client).consensus(repo.squads['sq-1']!, 'tv');
      expect(requests.single.url.path, '/rest/v1/rpc/calculate_squad_canon');
      expect(jsonDecode(requests.single.body), {'p_squad_id': 'sq-1', 'p_media_type': 'tv'});
      expect((board.single.championDisplayName, board.single.lowestDisplayName), ('Jordan', 'Alex'));
      expect(board.single.posterUrl, 'https://image.tmdb.org/t/p/w342/bb.jpg');
    });
  
    SupabaseClient clientReturning(List<Object> body, List<http.Request> requests) => SupabaseClient(
          'http://supabase.test',
          'anon-key',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), 200,
                headers: {'content-type': 'application/json'}, request: req);
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

    test('mySquads calls get_my_squads and maps role, count and previews (FE-SQUADS-03)', () async {
      final requests = <http.Request>[];
      final squads = await SupabaseSquadRepository(clientReturning([
        {
          'id': 'sq-1',
          'name': 'The Apartment',
          'description': null,
          'avatar_url': null,
          'created_by': 'u1',
          'created_at': '2026-01-01T00:00:00+00:00',
          'my_role': 'ADMIN',
          'member_count': 6,
          'member_previews': [
            {'user_id': 'u1', 'username': 'jordan', 'display_name': 'Jordan', 'avatar_url': null, 'role': 'OWNER', 'joined_at': '2026-01-01T00:00:00+00:00'},
            {'user_id': 'u3', 'username': 'alex', 'display_name': 'Alex', 'avatar_url': 'https://a/x.png', 'role': 'MEMBER', 'joined_at': '2026-01-02T00:00:00+00:00'},
          ],
        },
      ], requests))
          .mySquads();
      expect(requests.single.url.path, '/rest/v1/rpc/get_my_squads');
      final squad = squads.single;
      expect(squad.myRole, SquadRole.admin);
      expect(squad.memberCount, 6, reason: 'the full count, not the two previews');
      expect([for (final m in squad.members) (m.username, m.role)], [('jordan', SquadRole.owner), ('alex', SquadRole.member)]);
      expect(squad.members.last.avatarUrl, 'https://a/x.png');
    });

    test('deleteSquad deletes the squad row and fails when RLS removed nothing (FE-SQUADS-01)', () async {
      final requests = <http.Request>[];
      await SupabaseSquadRepository(clientReturning([{'id': 'sq-1'}], requests)).deleteSquad('sq-1');
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/rest/v1/squads');
      expect(requests.single.url.queryParameters['id'], 'eq.sq-1');

      expect(() => SupabaseSquadRepository(clientReturning([], [])).deleteSquad('sq-1'), throwsStateError);
    });

    test('leaveSquad deletes only my membership (FE-SQUADS-01)', () async {
      final requests = <http.Request>[];
      await SupabaseSquadRepository(clientReturning([{'squad_id': 'sq-1'}], requests), currentUserId: () => 'u3')
          .leaveSquad('sq-1');
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/rest/v1/squad_members');
      expect(requests.single.url.queryParameters, containsPair('squad_id', 'eq.sq-1'));
      expect(requests.single.url.queryParameters, containsPair('user_id', 'eq.u3'));
    });

    test('findInvitee calls lookup_squad_invitee and maps the match (FE-SQUADS-02)', () async {
      final requests = <http.Request>[];
      final invitee = await SupabaseSquadRepository(
        clientReturning([
          {'id': 'u2', 'username': 'maya', 'display_name': 'Maya Lin', 'avatar_url': null, 'matched_by': 'email'},
        ], requests),
      ).findInvitee(' maya@example.com ');
      expect(requests.single.url.path, '/rest/v1/rpc/lookup_squad_invitee');
      expect(jsonDecode(requests.single.body), {'p_query': 'maya@example.com'});
      expect(invitee!.userId, 'u2');
      expect(invitee.matchedByEmail, isTrue);

      expect(await SupabaseSquadRepository(clientReturning([], [])).findInvitee('nobody'), isNull);
    });
  });

  group('FE-SQUADS-02: invite input shapes', () {
    test('recognises emails and handles', () {
      expect(looksLikeEmail('maya@example.com'), isTrue);
      expect(looksLikeEmail(' Maya.Lin@Example.co.uk '), isTrue);
      expect(looksLikeEmail('maya@'), isFalse);
      expect(looksLikeEmail('@maya'), isFalse);

      expect(looksLikeHandle('@maya_l'), isTrue);
      expect(looksLikeHandle('Maya'), isTrue);
      expect(looksLikeHandle('ma'), isFalse);
      expect(looksLikeHandle('maya__l'), isFalse);
      expect(looksLikeHandle('maya lin'), isFalse);
    });
  });
}
