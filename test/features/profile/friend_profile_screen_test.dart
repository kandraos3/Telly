import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/friend_profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/friend_profile_screen.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../fakes/fake_social_repository.dart';
import '../../helpers/canon_seed.dart';
import '../../helpers/router_harness.dart';

CanonEntry entry(int id, String title, int rank, double score, {String mediaType = 'tv', String? review}) =>
    CanonEntry(
      id: id,
      title: title,
      mediaType: mediaType,
      rankPosition: rank,
      calculatedScore: score,
      shortReview: review,
    );

void main() {
  late AppDatabase db;
  late FakeProfileRepository profiles;
  late FakeSocialRepository social;
  late FakeAuthRepository auth;

  setUp(() async {
    db = AppDatabase.inMemory();
    profiles = FakeProfileRepository();
    social = FakeSocialRepository();
    auth = FakeAuthRepository(signedInUserId: 'u-me');
    profiles.profiles['maya'] =
        const PublicProfile(id: 'u-maya', username: 'maya', displayName: 'Maya Lin', bio: 'Severance truther');
    profiles.matches[('u-maya', 'movie')] = const CanonMatch(92, 4);
    profiles.matches[('u-maya', 'tv')] = const CanonMatch(84, 12);
    profiles.canons[('u-maya', 'tv')] = [
      entry(1, 'Succession', 1, 10.0, review: 'The sharpest dialogue on television.'),
      entry(2, 'Game of Thrones', 2, 9.7),
      entry(3, 'Station Eleven', 3, 9.4),
    ];
    // Mine: Succession #1 (agree), Game of Thrones last (clash); Station Eleven unseen (gem).
    await seedCanon(db, 'tv', ['Succession', 'X', 'Y', 'Z', 'Game of Thrones'], baseId: 1);
    // seedCanon numbers ids 1..5; move the fillers out of the way of Maya's titles.
    for (final (title, id) in [('X', 20), ('Y', 30), ('Z', 40)]) {
      await db.customStatement('UPDATE local_rankings SET show_id = ? WHERE title = ?', [id, title]);
    }
    await db.customStatement('UPDATE local_rankings SET show_id = 2 WHERE title = ?', ['Game of Thrones']);
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {String handle = 'maya', bool settle = true, AuthRepository? authRepo}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(FriendProfileScreen(handle: handle), overrides: [
      databaseProvider.overrideWithValue(db),
      profileRepositoryProvider.overrideWithValue(profiles),
      socialRepositoryProvider.overrideWithValue(social),
      authRepositoryProvider.overrideWithValue(authRepo ?? auth),
    ]));
    if (settle) await tester.pumpAndSettle();
  }

  group('FE-608: SCR-15 FriendProfileScreen', () {
    testWidgets('shows a loader, then the profile with blended and per-canon matches', (tester) async {
      profiles.gate = Completer<void>();
      await pump(tester, settle: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('Severance truther'), findsOneWidget);
      // (92·4 + 84·12) / 16 = 86
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Based on 16 mutual titles ranked'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('84%'), findsOneWidget);
    });

    testWidgets('agreements, clashes and gems come from both canons', (tester) async {
      await pump(tester);
      expect(find.text('Succession'), findsOneWidget, reason: 'agreement: both rank it #1');
      expect(find.text('Game of Thrones'), findsOneWidget, reason: 'clash: their #2, my last');
      expect(find.text('Station Eleven'), findsOneWidget, reason: "gem: their #3, I haven't ranked it");

      await tester.ensureVisible(find.text('+ Queue').first);
      await tester.tap(find.text('+ Queue').first);
      await tester.pumpAndSettle();
      expect(social.queued.single, (3, true));
    });

    testWidgets('follow toggles through the social repository', (tester) async {
      await pump(tester);
      expect(find.text('+ Follow'), findsOneWidget);
      await tester.tap(find.byKey(const Key('follow_button')));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(social.follows['u-maya'], FollowStatus.accepted);

      await tester.tap(find.byKey(const Key('follow_button')));
      await tester.pumpAndSettle();
      expect(find.text('+ Follow'), findsOneWidget);
    });

    testWidgets('a friends-only profile shows a card and a follow request, not the canon', (tester) async {
      profiles.profiles['private_pat'] = const PublicProfile(
        id: 'u-pat',
        username: 'private_pat',
        displayName: 'Pat',
        visibility: 'FRIENDS_ONLY',
        canView: false,
      );
      social.privateUsers.add('u-pat');
      await pump(tester, handle: 'private_pat');
      expect(find.byKey(const Key('friend_profile_private')), findsOneWidget);
      expect(find.textContaining('Two-to-Watch'), findsNothing);

      await tester.tap(find.byKey(const Key('follow_button')));
      await tester.pumpAndSettle();
      expect(find.text('Requested'), findsOneWidget);
      expect(find.textContaining('Follow request sent'), findsOneWidget);
    });

    testWidgets('an unknown handle renders not-found', (tester) async {
      await pump(tester, handle: 'nobody');
      expect(find.text("We couldn't find @nobody."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed load renders a retryable error', (tester) async {
      profiles.failReads = true;
      await pump(tester);
      expect(find.byKey(const Key('friend_profile_error')), findsOneWidget);
      profiles.failReads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Maya Lin'), findsOneWidget);
    });

    testWidgets('Two-to-Watch pushes /u/:handle/two-to-watch (SCR-16)', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('🍿 Two-to-Watch with @maya'));
      await tester.tap(find.text('🍿 Two-to-Watch with @maya'));
      await tester.pumpAndSettle();
      expect(find.text('route:/u/maya/two-to-watch'), findsOneWidget);
    });

    testWidgets('viewing own profile shows Edit Profile, 100% Taste Twin match, hides follow & Two-to-Watch, and navigates to edit profile', (tester) async {
      final authRepo = FakeAuthRepository(
        signedInUserId: 'u-maya',
        profile: UserProfile(id: 'u-maya', username: 'maya', displayName: 'Maya Lin', createdAt: DateTime(2026)),
      );
      await pump(tester, handle: 'maya', authRepo: authRepo);
      expect(find.byKey(const Key('follow_button')), findsNothing);
      expect(find.byKey(const Key('edit_profile_button')), findsOneWidget);
      expect(find.textContaining('Two-to-Watch'), findsNothing);

      // ALGO-TASTE-01: Self taste match evaluates to 100% Taste Twins
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Taste Twins'), findsOneWidget);
      expect(find.textContaining('shared'), findsWidgets);

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();
      expect(find.text('route:/canon/edit'), findsOneWidget);
    });
  });

  group('FE-608: TasteComparisons', () {
    test('never compares across canons and ranks by score gap', () {
      final lists = TasteComparisons.build(
        mine: {
          'movie': [entry(1, 'Heat', 1, 10.0, mediaType: 'movie')],
          'tv': [entry(1, 'Same id, other canon', 1, 10.0)],
        },
        theirs: {
          'movie': [entry(1, 'Heat', 3, 8.1, mediaType: 'movie')],
          'tv': const [],
        },
      );
      expect(lists.agreements.single.title, 'Heat');
      expect(lists.agreements.single.mediaType, 'movie');
      expect(lists.clashes, isEmpty, reason: 'a title is never both an agreement and a clash');
      expect(lists.gems, isEmpty);
    });
  });
}
