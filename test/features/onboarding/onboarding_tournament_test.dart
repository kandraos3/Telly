import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/onboarding/domain/onboarding_tournament.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';

List<CanonCandidate> picks(int movies, int series) => [
      for (var i = 0; i < movies; i++) CanonCandidate(titleId: 100 + i, mediaType: 'movie', title: 'M$i'),
      for (var i = 0; i < series; i++) CanonCandidate(titleId: 200 + i, mediaType: 'tv', title: 'S$i'),
    ];

/// Plays the tournament, answering with [prefer] (true = candidate wins).
OnboardingTournament play(OnboardingTournament t, bool Function(OnboardingDuel d) prefer) {
  var guard = 0;
  while (!t.isComplete) {
    final d = t.current!;
    expect(d.candidate.mediaType, d.mediaType);
    expect(d.opponent.mediaType, d.mediaType, reason: 'a film never duels a series');
    t.vote(candidateWins: prefer(d));
    expect(++guard, lessThan(50));
  }
  return t;
}

void main() {
  group('FE-606: OnboardingTournament (features/01 Screen 4)', () {
    test('8+ picks take 5–7 duels; two full canons split them 3 + 4', () {
      for (final (m, s) in [(4, 4), (3, 5), (5, 3), (8, 8), (2, 6), (1, 7)]) {
        final t = play(OnboardingTournament(picks(m, s)), (_) => true);
        expect(t.duelCount, inInclusiveRange(5, 7), reason: '$m movies / $s series');
      }
      final even = play(OnboardingTournament(picks(8, 8)), (_) => false);
      expect([even.duels('movie').length, even.duels('tv').length], [3, 4]);
    });

    test('a single-canon selection gets the whole 7-duel budget', () {
      final t = play(OnboardingTournament(picks(0, 10)), (_) => false);
      expect(t.duelCount, inInclusiveRange(5, 7));
      expect(t.ranked('movie'), isEmpty);
      expect(t.ranked('tv'), hasLength(10));
    });

    test('every pick lands in exactly one canon, ranked by the votes', () {
      // Prefer lower ids: the true order is M0 > M1 > M2 within the sorted head.
      final t = play(OnboardingTournament(picks(3, 4)), (d) => d.candidate.titleId < d.opponent.titleId);
      expect(t.ranked('movie').map((c) => c.title), ['M0', 'M1', 'M2']);
      expect(t.ranked('tv').map((c) => c.titleId).toSet(), {200, 201, 202, 203});
      // 4 series duels cannot fully sort 4 titles; the head is still exact.
      expect(t.ranked('tv').take(2).map((c) => c.title), ['S0', 'S1']);
    });

    test('random answers never break the budget or lose a title', () {
      final rng = Random(42);
      for (var run = 0; run < 200; run++) {
        final m = rng.nextInt(9), s = rng.nextInt(9);
        final t = play(OnboardingTournament(picks(m, s)), (_) => rng.nextBool());
        expect(t.duelCount, lessThanOrEqualTo(OnboardingTournament.maxTotalDuels));
        if (m + s >= 8 && max(m, s) >= 4) {
          // Enough titles to need calibration: never fewer than the spec's 5 decisions.
          expect(t.duelCount, greaterThanOrEqualTo(5), reason: '$m movies / $s series');
        }
        expect(t.ranked('movie'), hasLength(m));
        expect(t.ranked('tv'), hasLength(s));
        expect(t.ranked('movie').toSet(), hasLength(m), reason: 'no duplicates');
      }
    });

    test('"Too different / Hard to say" spends a duel but records none', () {
      final t = OnboardingTournament(picks(4, 0));
      t.skip();
      expect(t.duelCount, 1);
      expect(t.duels('movie'), isEmpty);
    });

    test('one title per canon needs no duels', () {
      final t = OnboardingTournament(picks(1, 1));
      expect(t.isComplete, isTrue);
      expect(t.duelCount, 0);
    });

    test('progress label follows the spec', () {
      final t = OnboardingTournament(picks(3, 4));
      expect(t.current!.progressLabel, 'Movie Duel 1 of 3 • Calibrating your Movie Rankings');
    });
  });
}
