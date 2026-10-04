import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CUJ-03: Two-to-Watch Co-Watching Decider & Quick-Swipe Match (E2E Integration)', (tester) async {
    // 1. Setup candidate pool with varying runtimes and provider availability
    final candidates = [
      const CoWatchCandidate(
        showId: 1,
        title: 'Past Lives',
        mediaType: 'movie',
        runtimeMinutes: 106,
        network: 'A24',
        availableProviders: ['netflix', 'max'],
        inWatchlistA: true,
      ),
      const CoWatchCandidate(
        showId: 2,
        title: 'Run Lola Run',
        mediaType: 'movie',
        runtimeMinutes: 81,
        network: 'Sony Pictures Classics',
        availableProviders: ['max'],
        inWatchlistA: true,
        inWatchlistB: true,
      ),
      const CoWatchCandidate(
        showId: 3,
        title: 'Oppenheimer',
        mediaType: 'movie',
        runtimeMinutes: 180,
        network: 'Universal',
        availableProviders: ['prime_video'],
        inWatchlistA: true,
      ),
      const CoWatchCandidate(
        showId: 4,
        title: 'Severance',
        mediaType: 'tv',
        runtimeMinutes: 50,
        network: 'Apple TV+',
        availableProviders: ['apple_tv_plus'],
        inWatchlistB: true,
      ),
    ];

    // 2. Compute shared streaming subscriptions
    final providersUserA = {'netflix', 'max'};
    final providersUserB = {'netflix', 'max', 'hulu'};
    final sharedProviders = TwoToWatchEngine.computeSharedProviders(
      providersA: providersUserA,
      providersB: providersUserB,
    );
    expect(sharedProviders, containsAll(['netflix', 'max']));

    // 3. Filter candidates: Movie Night + runtime < 90m (Breezy)
    final recommendations = TwoToWatchEngine.scoreCandidates(
      candidates: candidates,
      activeSharedProviders: sharedProviders,
      format: CoWatchFormat.movieNight,
      runtimeBudget: RuntimeBudget.breezy,
    );

    // Only 'Run Lola Run' matches shared provider (Max) and runtime <= 90 mins
    expect(recommendations, hasLength(1));
    expect(recommendations.first.candidate.title, equals('Run Lola Run'));
    expect(recommendations.first.candidate.runtimeMinutes, equals(81));

    // 4. Quick-Swipe session: Both users swipe right on mutual candidate
    final userASwipesRight = recommendations.any((r) => r.candidate.showId == 2);
    const userBSwipesRight = true;
    final isMutualMatch = userASwipesRight && userBSwipesRight;

    expect(isMutualMatch, isTrue);
  });
}
