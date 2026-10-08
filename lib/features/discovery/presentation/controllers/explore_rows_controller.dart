import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/discovery_repository.dart';
import '../../domain/explore_candidates.dart';
import '../../domain/explore_ranker.dart';

/// The clock Explore ranks and ages its cache by; overridden in tests.
final exploreNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Explore's ranked rows for one canon, and where they came from (features/07 §7.5).
class ExploreRowsState {
  final ExploreRows rows;

  /// When the payload behind [rows] was fetched.
  final DateTime savedAt;

  /// The last fetch failed, so [rows] come from the cache ("Offline. Showing picks from …").
  final bool isOffline;

  const ExploreRowsState({required this.rows, required this.savedAt, this.isOffline = false});

  ExploreRowsState copyWith({bool? isOffline}) =>
      ExploreRowsState(rows: rows, savedAt: savedAt, isOffline: isOffline ?? this.isOffline);
}

/// Cache first, then the network: a cached payload is ranked and shown at once, and refetched
/// in the background when older than [staleAfter]. With no cache, the first fetch decides
/// (an error state when it fails). Seeds the payload reports missing are sent to
/// `title-related` once per build, followed by one refetch.
class ExploreRowsController extends FamilyAsyncNotifier<ExploreRowsState, String> {
  static const staleAfter = Duration(hours: 6);
  static const _ranker = ExploreRanker();

  bool _relatedRequested = false;

  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);
  ExploreCacheDao get _cache => ref.read(exploreCacheDaoProvider);
  DateTime _now() => ref.read(exploreNowProvider)();

  @override
  Future<ExploreRowsState> build(String mediaType) async {
    _relatedRequested = false;
    final cached = await _readCache();
    if (cached == null) return _fetch();
    if (_now().difference(cached.savedAt) >= staleAfter) unawaited(_refreshInBackground());
    return cached;
  }

  /// Pull-to-refresh: always refetches. On failure the current rows stay, marked offline.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = current != null ? AsyncData(current.copyWith(isOffline: true)) : AsyncError(e, st);
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetch();
      state = AsyncData(fresh);
    } catch (_) {
      final current = state.valueOrNull;
      if (current != null) state = AsyncData(current.copyWith(isOffline: true));
    }
  }

  Future<ExploreRowsState> _fetch() async {
    var json = await _repo.fetchExploreCandidates(arg);
    final missing = ExploreCandidates.fromJson(json).profile.missingRelated;
    if (missing.isNotEmpty && !_relatedRequested) {
      _relatedRequested = true;
      try {
        await _repo.refreshRelated(missing, arg);
        json = await _repo.fetchExploreCandidates(arg);
      } catch (_) {
        // The first payload is still good; the scheduled refresh fills the gaps later.
      }
    }
    final savedAt = _now();
    try {
      await _cache.write(arg, jsonEncode(json), savedAt);
    } catch (_) {
      // A failed cache write must not hide fresh rows.
    }
    return _rank(json, savedAt);
  }

  Future<ExploreRowsState?> _readCache() async {
    try {
      final row = await _cache.read(arg);
      if (row == null) return null;
      return _rank(jsonDecode(row.json) as Map<String, dynamic>, row.savedAt);
    } catch (_) {
      return null; // unreadable cache: treat as none
    }
  }

  ExploreRowsState _rank(Map<String, dynamic> json, DateTime savedAt) => ExploreRowsState(
        rows: _ranker.rank(ExploreCandidates.fromJson(json), _now()),
        savedAt: savedAt,
      );
}

/// Explore's rows per canon (`'movie'` or `'tv'`).
final exploreRowsProvider =
    AsyncNotifierProvider.family<ExploreRowsController, ExploreRowsState, String>(ExploreRowsController.new);
