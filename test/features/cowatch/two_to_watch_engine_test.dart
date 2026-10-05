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
        ratingA: 9.0,
      );

      const unrankedShow = CoWatchCandidate(
        showId: 3,
        title: 'Fargo',
        mediaType: 'tv',
        network: 'FX',
        availableProviders: ['max'],
        inWatchlistA: false,
        inWatchlistB: false,
        communityScore: 8.0,
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

    test('reproduces §3.1 and §5.1 formula terms: w1(+50), w2*Taste*Rating, w3*Popularity, GodTier(+35), Vibe(+20)', () {
      // 1. Chernobyl: In both watchlists (+50), matches miniseries vibe (+20), communityScore 9.8
      // w2 * 0.88 * 9.8 = 21.56
      // w3 * 0.98 = 9.8
      // Expected = 50 + 20 + 21.56 + 9.8 = 101.4
      const chernobyl = CoWatchCandidate(
        showId: 101,
        title: 'Chernobyl',
        mediaType: 'tv',
        network: 'HBO',
        availableProviders: ['max'],
        vibeTags: ['miniseries', 'thriller'],
        inWatchlistA: true,
        inWatchlistB: true,
        communityScore: 9.8,
      );

      // 2. Squid Game: Partner ranked 9.4 (God Tier >= 9.20), you haven't seen (+35), no vibe match
      // w2 * 0.88 * 9.4 = 20.68
      // w3 * 0.85 = 8.5
      // Expected = 35 + 20.68 + 8.5 = 64.2
      const squidGame = CoWatchCandidate(
        showId: 102,
        title: 'Squid Game',
        mediaType: 'tv',
        network: 'Netflix',
        availableProviders: ['netflix'],
        vibeTags: ['survival', 'drama'],
        ratingB: 9.4,
        communityScore: 8.5,
      );

      // 3. Single Watchlist Title (no invented +20 bonus): inWatchlistA only, communityScore 8.0
      // w2 * 0.88 * 8.0 = 17.6
      // w3 * 0.80 = 8.0
      // Expected = 0 + 0 + 17.6 + 8.0 = 25.6
      const singleWatchlist = CoWatchCandidate(
        showId: 103,
        title: 'Severance',
        mediaType: 'tv',
        network: 'Apple TV+',
        availableProviders: ['apple_tv_plus'],
        inWatchlistA: true,
        inWatchlistB: false,
        communityScore: 8.0,
      );

      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [chernobyl, squidGame, singleWatchlist],
        activeSharedProviders: {'max', 'netflix', 'apple_tv_plus'},
        format: CoWatchFormat.series,
        selectedVibes: ['miniseries'],
        tasteMatchPercentage: 88,
      );

      expect(results.length, 3);
      expect(results[0].candidate.title, 'Chernobyl');
      expect(results[0].score, 101.4);
      expect(results[0].matchReason, contains('On both of your watchlists'));
      expect(results[0].matchReason, contains('Matches selected vibe'));

      expect(results[1].candidate.title, 'Squid Game');
      expect(results[1].score, 64.2);
      expect(results[1].matchReason, contains('Partner rated it ★9.4 (God Tier)'));

      expect(results[2].candidate.title, 'Severance');
      expect(results[2].score, 25.6);
      expect(results[2].matchReason, isNot(contains('Saved on watchlist')));
    });
  });

  group('FE-COWATCH-02: vibes match TMDB genres and can filter', () {
    const heat = CoWatchCandidate(
        showId: 949, title: 'Heat', mediaType: 'movie', network: 'WB', vibeTags: ['Action', 'Crime', 'Drama'], communityScore: 8.9);
    const arrival = CoWatchCandidate(
        showId: 329865, title: 'Arrival', mediaType: 'movie', network: 'Paramount', vibeTags: ['Science Fiction', 'Drama']);
    const parasite = CoWatchCandidate(
        showId: 496243, title: 'Parasite', mediaType: 'movie', network: 'Neon', vibeTags: ['Comedy', 'Thriller', 'Drama'], communityScore: 9.7);

    test('each vibe matches its genres case-insensitively, plus its own id', () {
      expect(CoWatchVibe.thriller.matches(heat), isTrue, reason: 'Crime');
      expect(CoWatchVibe.sciFi.matches(arrival), isTrue);
      expect(CoWatchVibe.sciFi.matches(heat), isFalse);
      expect(CoWatchVibe.comedy.matches(parasite), isTrue);
      expect(CoWatchVibe.any.matches(arrival), isTrue);
      expect(CoWatchVibe.festivalDarling.matches(parasite), isTrue, reason: 'acclaimed drama');
      expect(CoWatchVibe.festivalDarling.matches(heat), isFalse);
      expect(
        CoWatchVibe.thriller.matches(const CoWatchCandidate(showId: 1, title: 'x', mediaType: 'movie', network: '', vibeTags: ['thriller'])),
        isTrue,
      );
    });

    test('requireVibe drops titles outside the selected vibes', () {
      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [heat, arrival, parasite],
        activeSharedProviders: const {},
        format: CoWatchFormat.movieNight,
        selectedVibes: ['sci_fi'],
        requireVibe: true,
      );
      expect(results.map((r) => r.candidate.title), ['Arrival']);
      expect(results.single.matchReason, contains('Matches selected vibe'));
    });

    test('"Anything good" keeps every title without awarding the vibe bonus', () {
      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [heat, arrival],
        activeSharedProviders: const {},
        format: CoWatchFormat.movieNight,
        selectedVibes: ['any'],
        requireVibe: true,
      );
      expect(results, hasLength(2));
      expect(results.every((r) => !r.matchReason.contains('Matches selected vibe')), isTrue);
    });

    test('without requireVibe a vibe is only a bonus (Spec 05 §3.1)', () {
      final results = TwoToWatchEngine.scoreCandidates(
        candidates: [heat, arrival],
        activeSharedProviders: const {},
        format: CoWatchFormat.movieNight,
        selectedVibes: ['sci_fi'],
      );
      expect(results, hasLength(2));
      expect(results.first.candidate.title, 'Arrival');
    });

    test('queuedByMe marks my watchlist without touching the rest', () {
      const c = CoWatchCandidate(showId: 9, title: 'Dune', mediaType: 'movie', network: 'WB', inWatchlistB: true, ratingB: 9.3);
      final queued = c.queuedByMe();
      expect(queued.inWatchlistA, isTrue);
      expect(queued.inBothWatchlists, isTrue);
      expect(queued.ratingB, 9.3);
    });
  });
}
