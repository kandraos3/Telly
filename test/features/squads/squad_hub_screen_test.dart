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
      expect(find.text('THE APARTMENT (2)'), findsOneWidget);
      expect(find.text('MEMBERS (2)'), findsOneWidget);
      expect(find.byKey(const Key('squad_consensus_101')), findsOneWidget);
      expect(find.textContaining("SQUAD'S BIGGEST DEBATE: LOST"), findsOneWidget);
      expect(find.textContaining('Divergence: 64 ranks'), findsOneWidget);
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
      expect(find.text('MEMBERS (3)'), findsOneWidget);
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
      expect(find.text('THE APARTMENT (2)'), findsOneWidget);
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
      expect(find.text('THE APARTMENT (2)'), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('squad_create_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('route:/squads/sq-new'), findsOneWidget);
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
