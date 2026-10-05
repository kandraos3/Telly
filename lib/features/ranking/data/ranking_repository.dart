import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/editorial_tagging.dart';
import '../domain/score_curve_calculator.dart';

/// A title entering (or re-entering) a canon through the duel loop.
class CanonCandidate {
  final int titleId;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String? posterPath;

  const CanonCandidate({required this.titleId, required this.mediaType, required this.title, this.posterPath});
}

/// One decided duel; ties / "can't compare" are not recorded.
class LoggedDuel {
  final int winnerTitleId;
  final int loserTitleId;
  final int? decisionTimeMs;

  const LoggedDuel({required this.winnerTitleId, required this.loserTitleId, this.decisionTimeMs});
}

/// Result of committing a placement: what `SCR-12` reveals.
class RankingCommit {
  final String mutationId;
  final CanonCandidate candidate;
  final int rank;
  final double score;

  /// The canon after the commit, ordered by rank.
  final List<LocalRanking> canon;

  /// True when the title was already ranked (Reset Duels / re-log) and was moved.
  final bool wasMove;

  const RankingCommit({
    required this.mutationId,
    required this.candidate,
    required this.rank,
    required this.score,
    required this.canon,
    required this.wasMove,
  });

  int get total => canon.length;

  /// The title directly above the new entry, if any.
  String? get justBehind => rank > 1 ? canon[rank - 2].title : null;

  /// Titles directly below the new entry (the ones it beat).
  List<String> beating([int count = 2]) => canon.skip(rank).take(count).map((r) => r.title).toList();
}

/// A ranking row fetched from Supabase for pull-hydration.
class RemoteRanking {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int rank;
  final double score;
  final String? favoriteCharacter;

  const RemoteRanking({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    required this.rank,
    required this.score,
    this.favoriteCharacter,
  });
}

/// Local-first canon repository (FE-604, TA-04 §3).
///
/// Every mutation rewrites the affected Drift canon **and** appends a [PendingMutations]
/// row in one transaction, so the UI updates at 0 ms and the server replay (FE-605) can
/// never miss a change. Canons are always read and written per media type.
class RankingRepository {
  RankingRepository(this._db);

  final AppDatabase _db;
  LocalRankingDao get _rankings => _db.localRankingDao;
  PendingMutationDao get _queue => _db.pendingMutationDao;

  Stream<List<LocalRanking>> watchCanon(String mediaType) => _rankings.watchRankingsByCanon(mediaType);

  Future<List<LocalRanking>> getCanon(String mediaType) => _rankings.getRankingsByCanon(mediaType);

  /// Places [candidate] at [targetRank] after a duel tournament. A title that is already
  /// ranked is moved instead (features/02 §7.2), keeping its editorial data.
  Future<RankingCommit> commitPlacement({
    required CanonCandidate candidate,
    required int targetRank,
    List<LoggedDuel> duels = const [],
    String status = 'COMPLETED',
    bool isRewatch = false,
    String? bracket,
    bool broadcast = true,
  }) {
    final mediaType = candidate.mediaType;
    _requireCanon(mediaType);
    return _db.transaction(() async {
      final canon = await getCanon(mediaType);
      final existingIndex = canon.indexWhere((r) => r.showId == candidate.titleId);
      final existing = existingIndex >= 0 ? canon.removeAt(existingIndex) : null;

      final index = (targetRank - 1).clamp(0, canon.length);
      canon.insert(
        index,
        LocalRanking(
          showId: candidate.titleId,
          mediaType: mediaType,
          title: candidate.title,
          posterPath: candidate.posterPath ?? existing?.posterPath,
          rankPosition: index + 1,
          calculatedScore: 0,
          bracket: bracket ?? existing?.bracket,
          favoriteCharacter: existing?.favoriteCharacter,
          syncStatus: 'PENDING',
          updatedAt: DateTime.now(),
        ),
      );
      final rescored = await _writeCanon(canon, pendingTitleId: candidate.titleId);

      final duelPayload = [
        for (final d in duels)
          {
            'client_mutation_id': const Uuid().v4(),
            'winner_title_id': d.winnerTitleId,
            'loser_title_id': d.loserTitleId,
            'media_type': mediaType,
            'decision_time_ms': d.decisionTimeMs,
          },
      ];
      final mutationId = existing == null
          ? await _queue.enqueue(MutationKind.logTitle, {
              'title_id': candidate.titleId,
              'media_type': mediaType,
              'target_rank': index + 1,
              'status': status,
              'is_rewatch': isRewatch,
              'broadcast': broadcast,
              'duels': duelPayload,
            })
          : await _queue.enqueue(MutationKind.move, {
              'title_id': candidate.titleId,
              'media_type': mediaType,
              'new_rank': index + 1,
              'duels': duelPayload,
            });

      return RankingCommit(
        mutationId: mutationId,
        candidate: candidate,
        rank: index + 1,
        score: rescored[index].calculatedScore,
        canon: rescored,
        wasMove: existing != null,
      );
    });
  }

  /// Bulk-appends [ordered] (best first) below the existing canon in one transaction —
  /// the onboarding tournament and the Letterboxd/AniList importers (FE-606). Titles that
  /// are already ranked are skipped. Each title queues its own `log_title` mutation in
  /// rank order; the last one carries [duels]. Returns how many titles were added.
  Future<int> appendCanon({
    required String mediaType,
    required List<CanonCandidate> ordered,
    List<LoggedDuel> duels = const [],
    String? Function(CanonCandidate c)? bracketOf,
  }) {
    _requireCanon(mediaType);
    return _db.transaction(() async {
      final canon = await getCanon(mediaType);
      final ranked = canon.map((r) => r.showId).toSet();
      final added = <CanonCandidate>[];
      for (final c in ordered) {
        if (c.mediaType != mediaType) {
          throw ArgumentError('${c.title} is a ${c.mediaType}, not part of the $mediaType canon');
        }
        if (ranked.add(c.titleId)) added.add(c);
      }
      if (added.isEmpty) return 0;

      final start = canon.length;
      for (final c in added) {
        canon.add(LocalRanking(
          showId: c.titleId,
          mediaType: mediaType,
          title: c.title,
          posterPath: c.posterPath,
          rankPosition: canon.length + 1,
          calculatedScore: 0,
          bracket: bracketOf?.call(c),
          syncStatus: 'PENDING',
          updatedAt: DateTime.now(),
        ));
      }
      final now = DateTime.now();
      final n = canon.length;
      await _rankings.updateBatchRanks([
        for (var i = 0; i < n; i++)
          canon[i]
              .copyWith(
                rankPosition: i + 1,
                calculatedScore: ScoreCurveCalculator.calculateRoundedScore(i + 1, n),
                updatedAt: now,
              )
              .toCompanion(true),
      ]);

      final known = {for (final c in added) c.titleId};
      final duelPayload = [
        for (final d in duels)
          if (known.contains(d.winnerTitleId) || known.contains(d.loserTitleId))
            {
              'client_mutation_id': const Uuid().v4(),
              'winner_title_id': d.winnerTitleId,
              'loser_title_id': d.loserTitleId,
              'media_type': mediaType,
              'decision_time_ms': d.decisionTimeMs,
            },
      ];
      for (var i = 0; i < added.length; i++) {
        await _queue.enqueue(MutationKind.logTitle, {
          'title_id': added[i].titleId,
          'media_type': mediaType,
          'target_rank': start + i + 1,
          'status': 'COMPLETED',
          'is_rewatch': false,
          'duels': i == added.length - 1 ? duelPayload : const [],
        });
      }
      return added.length;
    });
  }

  /// Saves `SCR-11` editorial data for a ranked title (replayed as an UPDATE of the
  /// editorial columns, which RLS allows on one's own row).
  Future<void> attachEditorial({
    required int titleId,
    required String mediaType,
    required EditorialTaggingData data,
  }) {
    _requireCanon(mediaType);
    return _db.transaction(() async {
      final mvp = (data.mvpCharacter?.trim().isEmpty ?? true) ? null : data.mvpCharacter!.trim();
      await (_db.update(_db.localRankings)
            ..where((t) => t.showId.equals(titleId) & t.mediaType.equals(mediaType)))
          .write(LocalRankingsCompanion(favoriteCharacter: Value(mvp)));
      final review = data.review.trim();
      await _queue.enqueue(MutationKind.editorial, {
        'title_id': titleId,
        'media_type': mediaType,
        'favorite_character': mvp,
        'review_short': review.isEmpty ? null : review,
        'tags': data.vibeTags,
        'is_rewatch': data.isRewatch,
        'rewatch_count': data.rewatchCount < 1 ? 1 : data.rewatchCount,
        'venue': data.viewingVenue?.dbValue,
        'audio_language': data.audioMode?.dbValue,
      });
    });
  }

  /// Manual re-ordering (drag-and-drop, features/02 §7.3). No-op for an unknown title.
  Future<void> move({required String mediaType, required int titleId, required int newRank}) {
    _requireCanon(mediaType);
    return _db.transaction(() async {
      final canon = await getCanon(mediaType);
      final from = canon.indexWhere((r) => r.showId == titleId);
      if (from < 0) return;
      final item = canon.removeAt(from);
      final to = (newRank - 1).clamp(0, canon.length);
      canon.insert(to, item);
      await _writeCanon(canon, pendingTitleId: titleId);
      await _queue.enqueue(MutationKind.move, {'title_id': titleId, 'media_type': mediaType, 'new_rank': to + 1});
    });
  }

  /// Removes a title from its canon and closes the rank gap.
  Future<void> remove({required String mediaType, required int titleId}) {
    _requireCanon(mediaType);
    return _db.transaction(() async {
      final canon = await getCanon(mediaType);
      final before = canon.length;
      canon.removeWhere((r) => r.showId == titleId);
      if (canon.length == before) return;
      await _rankings.deleteRanking(titleId, mediaType);
      await _writeCanon(canon);
      await _queue.enqueue(MutationKind.delete, {'title_id': titleId, 'media_type': mediaType});
    });
  }

  /// Pull-hydration: replaces both local canons with the server's when nothing local is
  /// waiting to sync (the local canon is then just a cache). Returns false if skipped.
  Future<bool> replaceFromRemote(List<RemoteRanking> remote) => _db.transaction(() async {
        if (await _queue.count() > 0) return false;
        for (final mediaType in const ['movie', 'tv']) {
          await _rankings.clearCanon(mediaType);
          final rows = remote.where((r) => r.mediaType == mediaType).toList()
            ..sort((a, b) => a.rank.compareTo(b.rank));
          await _rankings.updateBatchRanks([
            for (var i = 0; i < rows.length; i++)
              LocalRankingsCompanion.insert(
                showId: rows[i].titleId,
                mediaType: mediaType,
                title: rows[i].title,
                posterPath: Value(rows[i].posterPath),
                rankPosition: i + 1,
                calculatedScore: rows[i].score,
                favoriteCharacter: Value(rows[i].favoriteCharacter),
                syncStatus: const Value('SYNCED'),
              ),
          ]);
        }
        return true;
      });

  /// Re-ranks 1..N with curve scores and writes the canon. Only [pendingTitleId]'s row is
  /// marked PENDING; other rows keep their status (the server recomputes their scores).
  Future<List<LocalRanking>> _writeCanon(List<LocalRanking> ordered, {int? pendingTitleId}) async {
    final n = ordered.length;
    final now = DateTime.now();
    final rescored = [
      for (var i = 0; i < n; i++)
        ordered[i].copyWith(
          rankPosition: i + 1,
          calculatedScore: ScoreCurveCalculator.calculateRoundedScore(i + 1, n),
          syncStatus: ordered[i].showId == pendingTitleId ? 'PENDING' : ordered[i].syncStatus,
          updatedAt: now,
        ),
    ];
    await _rankings.updateBatchRanks([for (final r in rescored) r.toCompanion(true)]);
    return rescored;
  }

  static void _requireCanon(String mediaType) {
    if (mediaType != 'movie' && mediaType != 'tv') {
      throw ArgumentError.value(mediaType, 'mediaType', "must be 'movie' or 'tv'");
    }
  }
}

final rankingRepositoryProvider = Provider<RankingRepository>((ref) => RankingRepository(ref.watch(databaseProvider)));
