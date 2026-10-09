import 'dart:async';

import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

/// Tracks what it is given and never touches a database or the network. For screens that only
/// read tracking. Use the real repository over an in-memory database (`tracking_harness.dart`) to
/// test the writes.
class FakeTrackingRepository implements TrackingRepository {
  FakeTrackingRepository([List<TrackingItem> items = const []]) : _items = [...items];

  List<TrackingItem> _items;
  final _changes = StreamController<List<TrackingItem>>.broadcast();

  /// What `get_tracking_stats` answers; null reads as offline (it throws).
  TrackingStats? weekStats;

  /// Friends watching, for any title.
  TrackingWatchers watchersResult = const TrackingWatchers();

  /// Replaces everything tracked and tells listeners.
  set items(List<TrackingItem> items) {
    _items = [...items];
    _changes.add(_items);
  }

  @override
  Stream<List<TrackingItem>> watchAll() async* {
    yield _items;
    yield* _changes.stream;
  }

  @override
  Future<TrackingItem?> getOne(int titleId, String mediaType) async {
    for (final i in _items) {
      if (i.titleId == titleId && i.mediaType == mediaType) return i;
    }
    return null;
  }

  @override
  Future<void> hydrate() async {}

  /// Moves the place and tells listeners. The next episode is left as it was.
  @override
  Future<TrackingItem> setPlace(TrackingItem item, EpisodeRef? place) async {
    final moved = item.copyWith(place: place, clearPlace: place == null);
    items = [for (final i in _items) if (i.titleId == item.titleId && i.mediaType == item.mediaType) moved else i];
    return moved;
  }

  @override
  Future<TrackingStats> stats(String mediaType, {int? year}) async =>
      weekStats ?? (throw StateError('offline'));

  @override
  Future<TrackingWatchers> watchers(int titleId, String mediaType) async => watchersResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
