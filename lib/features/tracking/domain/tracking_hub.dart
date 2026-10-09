import 'tracking_group.dart';
import 'tracking_item.dart';
import 'tracking_models.dart';

/// The chips on `SCR-29` (features/11 §9.5). [query] is the `?filter=` value.
enum WatchingFilter {
  all('all'),
  tv('tv'),
  movie('movie'),
  finished('finished');

  const WatchingFilter(this.query);

  final String query;

  /// Unknown or missing values open on *All*.
  static WatchingFilter fromQuery(String? value) =>
      values.firstWhere((f) => f.query == value, orElse: () => WatchingFilter.all);
}

/// The sort sheet's two choices; they apply within each group (SCR-29).
enum WatchingSort { recent, fewestLeft }

class HubGroup {
  const HubGroup(this.group, this.items);

  final TrackingGroup group;
  final List<TrackingItem> items;
}

/// What `SCR-29` shows for a set of tracked titles at [now] (features/11 §2.3, §9.5).
class TrackingHub {
  TrackingHub(List<TrackingItem> items, this.now) : items = List.unmodifiable(items) {
    for (final item in items) {
      final g = item.group(now);
      if (g != null) _grouped[item] = g;
    }
  }

  final List<TrackingItem> items;
  final DateTime now;
  final Map<TrackingItem, TrackingGroup> _grouped = {};

  /// Titles in any group: *All*, *Series* and *Movies* count these, and never mix canons.
  int count(WatchingFilter filter) => switch (filter) {
        WatchingFilter.all => _grouped.length,
        WatchingFilter.tv => _grouped.keys.where((i) => !i.isMovie).length,
        WatchingFilter.movie => _grouped.keys.where((i) => i.isMovie).length,
        WatchingFilter.finished => items.where((i) => i.state == TrackingState.finished).length,
      };

  /// Whether anything is tracked at all (the *Empty* state).
  bool get isEmpty => items.isEmpty;

  TrackingGroup? groupOf(TrackingItem item) => _grouped[item];

  /// Groups in §2.3 order, empty ones omitted. *Finished* is a flat history, not groups.
  List<HubGroup> groups(WatchingFilter filter, WatchingSort sort) {
    if (filter == WatchingFilter.finished) return const [];
    final inFilter = _grouped.entries.where((e) => switch (filter) {
          WatchingFilter.tv => !e.key.isMovie,
          WatchingFilter.movie => e.key.isMovie,
          _ => true,
        });
    return [
      for (final g in TrackingGroup.values)
        if (inFilter.any((e) => e.value == g))
          HubGroup(g, _sorted([for (final e in inFilter) if (e.value == g) e.key], sort)),
    ];
  }

  /// Home's *Currently watching* rows (SCR-21): *New episodes*, then *In progress*, newest
  /// progress first, both canons mixed.
  List<TrackingItem> homeRows({int limit = 3}) {
    List<TrackingItem> of(TrackingGroup g) =>
        (_grouped.entries.where((e) => e.value == g).map((e) => e.key).toList()
          ..sort((a, b) => b.lastProgressAt.compareTo(a.lastProgressAt)));
    return [...of(TrackingGroup.newEpisodes), ...of(TrackingGroup.inProgress)].take(limit).toList();
  }

  /// "+ 1 caught up · 2 finished and waiting to be ranked", or null when there is nothing to add.
  String? homeCountLine() {
    final caught = _grouped.values.where((g) => g == TrackingGroup.caughtUp).length;
    final waiting = _grouped.values.where((g) => g == TrackingGroup.finishedNotRanked).length;
    final parts = [
      if (caught > 0) '$caught caught up',
      if (waiting > 0) '$waiting finished and waiting to be ranked',
    ];
    return parts.isEmpty ? null : '+ ${parts.join(' · ')}';
  }

  /// `FINISHED` titles by `finished_at`, newest first.
  List<TrackingItem> finishedHistory() {
    final done = items.where((i) => i.state == TrackingState.finished).toList()
      ..sort((a, b) => (b.finishedAt ?? b.lastProgressAt).compareTo(a.finishedAt ?? a.lastProgressAt));
    return done;
  }

  static List<TrackingItem> _sorted(List<TrackingItem> list, WatchingSort sort) {
    final out = [...list];
    switch (sort) {
      case WatchingSort.recent:
        out.sort((a, b) => b.lastProgressAt.compareTo(a.lastProgressAt));
      case WatchingSort.fewestLeft:
        // Series with the fewest episodes left first; movies and unknowns last, newest first.
        out.sort((a, b) {
          final l = a.episodesLeft, r = b.episodesLeft;
          if (l == null && r == null) return b.lastProgressAt.compareTo(a.lastProgressAt);
          if (l == null) return 1;
          if (r == null) return -1;
          final c = l.compareTo(r);
          return c != 0 ? c : b.lastProgressAt.compareTo(a.lastProgressAt);
        });
    }
    return out;
  }
}
