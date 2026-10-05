import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';

import '../../fakes/fake_social_repository.dart';
import '../../fakes/fake_watchlist_repository.dart';

void main() {
  group('FE-304 / FE-609: Feed Card 1-Tap Queue Integration', () {
    testWidgets('tapping bookmark toggles state and invokes WatchlistRepository', (tester) async {
      final fakeWatchlist = FakeWatchlistRepository();
      final socialRepo = SupabaseSocialRepository(
        SupabaseClient(
          'http://supabase.test',
          'anon-key',
          httpClient: MockClient((req) async => http.Response('null', 200)),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        currentUserId: () => 'u-me',
        watchlistRepository: fakeWatchlist,
      );

      final activity = fakeActivity('a1', userId: 'u-b', titleId: 110492, title: 'Severance');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialRepositoryProvider.overrideWithValue(socialRepo),
          ],
          child: MaterialApp(
            theme: TellyTheme.dark,
            home: Scaffold(
              body: FeedActivityCard(
                activity: activity,
                onQueueToggle: (inQueue) async {
                  await socialRepo.setQueued(activity: activity, queued: inQueue);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Want to Watch'), findsOneWidget);
      expect(await fakeWatchlist.isInWatchlist(110492, 'tv'), isFalse);

      // 1-Tap add to queue
      await tester.tap(find.byKey(const Key('feed_bookmark')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('In your Watchlist'), findsOneWidget);
      expect(await fakeWatchlist.isInWatchlist(110492, 'tv'), isTrue);
      expect(fakeWatchlist.items.single.title, 'Severance');
      expect(fakeWatchlist.items.single.mediaType, 'tv');

      // 1-Tap remove from queue
      await tester.tap(find.byKey(const Key('feed_bookmark')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Want to Watch'), findsOneWidget);
      expect(await fakeWatchlist.isInWatchlist(110492, 'tv'), isFalse);
    });
  });
}

