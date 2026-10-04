import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/cowatch/domain/spearman_taste_match_calculator.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';
import 'package:telly_app/features/ranking/domain/trueskill_confidence.dart';
import 'package:telly_app/features/squads/domain/squad_canon_aggregator.dart';

void main() {
  group('QA-607: Dart ↔ SQL Algorithmic Parity Suite', () {
    test('1. Score Curve: Dart ScoreCurveCalculator matches canonical fixture (score_curve_vectors.json)', () {
      final file = File('test/fixtures/score_curve_vectors.json');
      expect(file.existsSync(), isTrue);

      final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();

      for (final vec in vectors) {
        final n = vec['n'] as int;
        final rank = vec['rank'] as int;
        final expectedScore = (vec['score'] as num).toDouble();

        final actualScore = ScoreCurveCalculator.calculateScore(rank, n);
        expect(
          actualScore,
          closeTo(expectedScore, 0.01),
          reason: 'Failed for N=$n, rank=$rank: expected $expectedScore, got $actualScore',
        );
      }
    });

    test('2. Spearman Taste Match: Dart SpearmanTasteMatchCalculator matches canonical fixture (spearman_taste_match_vectors.json)', () {
      final file = File('test/fixtures/spearman_taste_match_vectors.json');
      expect(file.existsSync(), isTrue);

      final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();

      for (final vec in vectors) {
        final name = vec['name'] as String;
        final rawPairs = (vec['pairs'] as List).cast<Map<String, dynamic>>();
        final pairs = rawPairs.map((p) => (p['ra'] as int, p['rb'] as int)).toList();
        final expectedMatchPct = vec['match_pct'] as int;
        final expectedRawRho = (vec['raw_rho'] as num).toDouble();

        final result = SpearmanTasteMatchCalculator.calculate(pairedRanks: pairs);

        expect(
          result.matchPercentage,
          equals(expectedMatchPct),
          reason: 'Failed match_pct for test case "$name": expected $expectedMatchPct%, got ${result.matchPercentage}%',
        );
        expect(
          result.rawRho,
          closeTo(expectedRawRho, 0.01),
          reason: 'Failed rawRho for test case "$name": expected $expectedRawRho, got ${result.rawRho}',
        );
      }
    });

    test('3. Borda Squad Canon: Dart SquadCanonAggregator matches canonical fixture (borda_squad_canon_vectors.json)', () {
      final file = File('test/fixtures/borda_squad_canon_vectors.json');
      expect(file.existsSync(), isTrue);

      final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final members = (fixture['members'] as List).cast<Map<String, dynamic>>();
      final expectedConsensus = (fixture['expected_consensus'] as List).cast<Map<String, dynamic>>();

      final memberEntries = <MemberRankEntry>[];

      for (final m in members) {
        final userId = m['user_id'] as String;
        final displayName = m['display_name'] as String;
        final rankings = (m['rankings'] as List).cast<Map<String, dynamic>>();

        for (final r in rankings) {
          memberEntries.add(
            MemberRankEntry(
              userId: userId,
              displayName: displayName,
              titleId: r['title_id'] as int,
              title: r['title'] as String,
              rankPosition: r['rank'] as int,
              releaseYear: 2000,
              mediaType: 'movie',
            ),
          );
        }
      }

      final consensus = SquadCanonAggregator.calculateConsensusCanon(
        entries: memberEntries,
        mediaType: 'movie',
      );

      expect(consensus.length, equals(expectedConsensus.length));

      for (int i = 0; i < expectedConsensus.length; i++) {
        final exp = expectedConsensus[i];
        final actual = consensus[i];

        expect(actual.consensusRank, equals(exp['consensus_rank']), reason: 'Rank mismatch at position $i');
        expect(actual.titleId, equals(exp['title_id']), reason: 'TitleId mismatch at position $i');
        expect(actual.totalBordaPoints, equals(exp['total_borda_points']), reason: 'Points mismatch for ${actual.title}');
        expect(actual.membersRankedCount, equals(exp['members_ranked_count']), reason: 'Member count mismatch for ${actual.title}');
        expect(actual.championUserId, equals(exp['champion_user_id']), reason: 'Champion mismatch for ${actual.title}');
        expect(actual.championRank, equals(exp['champion_rank']), reason: 'Champion rank mismatch for ${actual.title}');
        expect(actual.lowestRank, equals(exp['lowest_rank']), reason: 'Lowest rank mismatch for ${actual.title}');
      }
    });

    test('4. Time-Decay & Uncertainty Shrinkage: TrueSkill confidence decays monotonically at 0.75 per duel', () {
      var confidence = TrueSkillConfidence.initial();
      expect(confidence.sigma, equals(1.20));
      expect(confidence.isLocked, isFalse);

      final sigmas = <double>[confidence.sigma];
      for (int duel = 1; duel <= 6; duel++) {
        confidence = confidence.recordDuel();
        sigmas.add(confidence.sigma);
        final expected = sigmas[duel - 1] * 0.75 > 0.15 ? sigmas[duel - 1] * 0.75 : 0.15;
        expect(confidence.sigma, closeTo(expected, 0.001));
      }

      // By duel 4: 1.20 * 0.75^4 = 0.3797 < 0.50 (status becomes locked)
      expect(sigmas[4], lessThan(0.50));
      expect(confidence.isLocked, isTrue);
    });

    test('5. pgTAP SQL Test Files Embed Matching Fixture Assertions', () {
      final scoreCurveSql = File('supabase/tests/database/003_score_curve_parity.test.sql').readAsStringSync();
      expect(scoreCurveSql, contains('public.canon_score(rank, n)'));

      final socialRpcsSql = File('supabase/tests/database/005_social_and_account_rpcs.test.sql').readAsStringSync();
      expect(socialRpcsSql, contains('public.calculate_taste_match_rpc'));
      expect(socialRpcsSql, contains('VALUES (72, 4)'));
      expect(socialRpcsSql, contains('VALUES (50, 1)'));

      final paritySql = File('supabase/tests/database/011_algorithmic_parity.test.sql').readAsStringSync();
      expect(paritySql, contains('calculate_taste_match_rpc'));
      expect(paritySql, contains('calculate_squad_canon'));
      expect(paritySql, contains('public.canon_score(1, 10)'));
    });
  });
}
