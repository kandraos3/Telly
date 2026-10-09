import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/domain/user_search_result.dart';
import 'package:telly_app/features/profile/presentation/screens/search_users_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

void main() {
  late FakeProfileRepository profileRepo;
  late FakeAuthRepository authRepo;

  setUp(() {
    profileRepo = FakeProfileRepository();
    authRepo = FakeAuthRepository(signedInUserId: 'me-123');
  });

  Future<void> pumpSearchScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      routerHarness(
        const SearchUsersScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SCR-28 SearchUsersScreen (epic #48)', () {
    testWidgets('renders app bar title, search input, and initial empty prompt', (tester) async {
      await pumpSearchScreen(tester);

      expect(find.text('Find Friends'), findsOneWidget);
      expect(find.byKey(const Key('user_search_input')), findsOneWidget);
      expect(find.text('Search by name or @handle...'), findsOneWidget);
      expect(find.byKey(const Key('user_search_empty_prompt')), findsOneWidget);
      expect(
        find.text("Search for friends by name or @handle to see what they're watching."),
        findsOneWidget,
      );
    });

    testWidgets('shows results and taste match badge after typing a query', (tester) async {
      profileRepo.searchResults.addAll([
        const UserSearchResult(
          id: 'u-1',
          username: 'alexm',
          displayName: 'Alex Morgan',
          avatarUrl: null,
          tasteMatch: 88,
          mutualCount: 2,
        ),
        const UserSearchResult(
          id: 'u-2',
          username: 'aross',
          displayName: 'Alexander Ross',
          avatarUrl: null,
          tasteMatch: 74,
          mutualCount: 1,
          followStatus: FollowStatus.pending,
        ),
        const UserSearchResult(
          id: 'u-3',
          username: 'alexchen',
          displayName: 'Alex Chen',
          avatarUrl: null,
          tasteMatch: null,
          mutualCount: 0,
          followStatus: FollowStatus.accepted,
        ),
      ]);

      await pumpSearchScreen(tester);

      await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('MATCHES'), findsOneWidget);
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('@alexm'), findsOneWidget);
      expect(find.text('🎯 88% Taste Match'), findsOneWidget);
      expect(find.text('+ Follow'), findsOneWidget);

      expect(find.text('Alexander Ross'), findsOneWidget);
      expect(find.text('@aross'), findsOneWidget);
      expect(find.text('🎯 74% Taste Match'), findsOneWidget);
      expect(find.text('Requested'), findsOneWidget);

      expect(find.text('Alex Chen'), findsOneWidget);
      expect(find.text('@alexchen'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('tapping user card outside follow button navigates to /u/:handle', (tester) async {
      profileRepo.searchResults.addAll([
        const UserSearchResult(
          id: 'u-1',
          username: 'alexm',
          displayName: 'Alex Morgan',
        ),
      ]);

      await pumpSearchScreen(tester);
      await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap on card
      await tester.tap(find.byKey(const Key('user_search_card_alexm')));
      await tester.pumpAndSettle();

      expect(find.text('route:/u/alexm'), findsOneWidget);
    });

    testWidgets('tapping follow button sends follow request and updates UI without navigating', (tester) async {
      profileRepo.searchResults.addAll([
        const UserSearchResult(
          id: 'u-1',
          username: 'alexm',
          displayName: 'Alex Morgan',
          followStatus: null,
        ),
      ]);

      await pumpSearchScreen(tester);
      await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('+ Follow'), findsOneWidget);

      // Tap follow button
      await tester.tap(find.byKey(const Key('user_search_follow_alexm')));
      await tester.pumpAndSettle();

      expect(profileRepo.follows.containsKey('u-1'), isTrue);
      expect(find.text('Following'), findsOneWidget);
      // Ensure we did not navigate away
      expect(find.text('route:/u/alexm'), findsNothing);
    });

    testWidgets('clear button clears input text and returns to empty prompt', (tester) async {
      profileRepo.searchResults.addAll([
        const UserSearchResult(
          id: 'u-1',
          username: 'alexm',
          displayName: 'Alex Morgan',
        ),
      ]);

      await pumpSearchScreen(tester);
      await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.byKey(const Key('user_search_clear_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('user_search_clear_button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_search_empty_prompt')), findsOneWidget);
      expect(find.text('Alex Morgan'), findsNothing);
    });

    testWidgets('shows no results message when query returns empty list', (tester) async {
      profileRepo.searchResults.clear();

      await pumpSearchScreen(tester);
      await tester.enterText(find.byKey(const Key('user_search_input')), 'nonexistent');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_search_no_results')), findsOneWidget);
      expect(find.text("No users found matching 'nonexistent'."), findsOneWidget);
    });

    testWidgets('shows error state with retry button on exception', (tester) async {
      profileRepo.failReads = true;

      await pumpSearchScreen(tester);
      await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_search_error')), findsOneWidget);
      expect(find.text('User search requires an internet connection.'), findsOneWidget);
      expect(find.byKey(const Key('user_search_retry_button')), findsOneWidget);

      // Fix error and retry
      profileRepo.failReads = false;
      profileRepo.searchResults.addAll([
        const UserSearchResult(
          id: 'u-1',
          username: 'alexm',
          displayName: 'Alex Morgan',
        ),
      ]);

      await tester.tap(find.byKey(const Key('user_search_retry_button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Alex Morgan'), findsOneWidget);
    });
  });
}
