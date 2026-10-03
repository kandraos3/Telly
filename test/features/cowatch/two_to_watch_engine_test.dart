import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';

void main() {
  group('QA-403: Two-to-Watch Joint Candidate Scoring & Provider Intersection Tests', () {
    test('computes intersection of streaming providers between user A and B', () {
      final providersA = {'netflix', 'max', 'hulu'};
      final providersB = {'max', 'apple_tv_plus', 'hulu'};

      final shared = TwoToWatchEngine.computeSharedProviders(
        providersA: providersA,
        providersB: providersB,
      );

      expect(shared, {'max', 'hulu'});
      expect(shared.contains('netflix'), isFalse);
      expect(shared.contains('apple_tv_plus'), isFalse);
    });

    test('ranks mutual watchlist titles higher than single watchlist or general titles', () {
      const mutualWatchlistShow = CoWatchCandidate(
        showId: 1,
        title: 'Chernobyl',
        mediaType: 'tv',
        network: 'HBO',
        availableProviders: ['max'],
        inWatchlistA: true,
        inWatchlistB: true,
      );

      const singleWatchlistShow = CoWatchCandidate(
        showId: 2,
        title: 'The Wire',
        mediaType: 'tv',
        network: 'HBO',
        availableProviders: ['max'],
        inWatchlistA: true,
        inWatchlistB: false,
      );

      const unrankedShow = CoWatchCandidate(
        showId: 3,
        title: 'Fargo',
        mediaType: 'tv',
        network: 'FX',
        availableProviders: ['max'],
        inWatchlistA: false,
        inWatchlistB: false,
      );

      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [unrankedShow, singleWatchlistShow, mutualWatchlistShow],
        activeSharedProviders: {'max'},
        format: CoWatchFormat.series,
        tasteMatchPercentage: 88,
      );

      expect(results.length, 3);
      expect(results[0].candidate.title, 'Chernobyl');
      expect(results[0].score, greaterThan(results[1].score));
      expect(results[1].candidate.title, 'The Wire');
      expect(results[1].score, greaterThan(results[2].score));
    });

    test('format toggle strictly segregates movies from tv series', () {
      const movieCandidate = CoWatchCandidate(
        showId: 10,
        title: 'Parasite',
        mediaType: 'movie',
        runtimeMinutes: 132,
        network: 'Neon',
        availableProviders: ['max'],
      );

      const tvCandidate = CoWatchCandidate(
        showId: 20,
        title: 'Severance',
        mediaType: 'tv',
        network: 'Apple TV+',
        availableProviders: ['max'],
      );

      // Select Movie Night
      final movieResults = TwoToWatchEngine.scoreCandidates(
        candidates: [movieCandidate, tvCandidate],
        activeSharedProviders: {'max'},
        format: CoWatchFormat.movieNight,
      );

      expect(movieResults.length, 1);
      expect(movieResults.first.candidate.title, 'Parasite');

      // Select Series
      final tvResults = TwoToWatchEngine.scoreCandidates(
        candidates: [movieCandidate, tvCandidate],
        activeSharedProviders: {'max'},
        format: CoWatchFormat.series,
      );

      expect(tvResults.length, 1);
      expect(tvResults.first.candidate.title, 'Severance');
    });

    test('runtime budget filters constrain movie candidates appropriately', () {
      const shortMovie = CoWatchCandidate(
        showId: 1,
        title: 'Run Lola Run',
        mediaType: 'movie',
        runtimeMinutes: 81,
        network: 'Sony',
        availableProviders: ['netflix'],
      );

      const standardMovie = CoWatchCandidate(
        showId: 2,
        title: 'Past Lives',
        mediaType: 'movie',
        runtimeMinutes: 106,
        network: 'A24',
        availableProviders: ['netflix'],
      );

      const epicMovie = CoWatchCandidate(
        showId: 3,
        title: 'Oppenheimer',
        mediaType: 'movie',
        runtimeMinutes: 180,
        network: 'Universal',
        availableProviders: ['netflix'],
      );

      final candidates = [shortMovie, standardMovie, epicMovie];

      // Test Breezy (< 90m)
      final breezyResults = TwoToWatchEngine.scoreCandidates(
        candidates: candidates,
        activeSharedProviders: {'netflix'},
        format: CoWatchFormat.movieNight,
        runtimeBudget: RuntimeBudget.breezy,
      );
      expect(breezyResults.length, 1);
      expect(breezyResults.first.candidate.title, 'Run Lola Run');

      // Test Standard (90-120m)
      final standardResults = TwoToWatchEngine.scoreCandidates(
        candidates: candidates,
        activeSharedProviders: {'netflix'},
        format: CoWatchFormat.movieNight,
        runtimeBudget: RuntimeBudget.standard,
      );
      expect(standardResults.length, 1);
      expect(standardResults.first.candidate.title, 'Past Lives');

      // Test Epic (120m+)
      final epicResults = TwoToWatchEngine.scoreCandidates(
        candidates: candidates,
        activeSharedProviders: {'netflix'},
        format: CoWatchFormat.movieNight,
        runtimeBudget: RuntimeBudget.epic,
      );
      expect(epicResults.length, 1);
      expect(epicResults.first.candidate.title, 'Oppenheimer');
    });

    test('filters out titles that are not on active shared providers', () {
      const showOnMax = CoWatchCandidate(
        showId: 1,
        title: 'Succession',
        mediaType: 'tv',
        network: 'HBO',
        availableProviders: ['max'],
      );

      const showOnHulu = CoWatchCandidate(
        showId: 2,
        title: 'Shogun',
        mediaType: 'tv',
        network: 'FX',
        availableProviders: ['hulu'],
      );

      // Shared providers only has Max
      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [showOnMax, showOnHulu],
        activeSharedProviders: {'max'},
        format: CoWatchFormat.series,
      );

      expect(results.length, 1);
      expect(results.first.candidate.title, 'Succession');
    });
  });
}
