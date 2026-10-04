import 'package:telly_app/features/queue/data/watchlist_repository.dart';

class FakeWatchlistRepository implements WatchlistRepository {
  final List<WatchlistEntry> items = [];

  @override
  Future<void> add({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {
    items.removeWhere((e) => e.titleId == titleId && e.mediaType == mediaType);
    items.add(WatchlistEntry(
      titleId: titleId,
      mediaType: mediaType,
      title: title,
      posterPath: posterPath,
      savedAt: DateTime.now(),
      syncStatus: 'PENDING',
    ));
  }

  @override
  Future<List<WatchlistEntry>> getWatchlist({String? mediaType}) async {
    if (mediaType != null) {
      return items.where((e) => e.mediaType == mediaType).toList();
    }
    return List.from(items);
  }

  @override
  Future<void> hydrate() async {}

  @override
  Future<bool> isInWatchlist(int titleId, String mediaType) async {
    return items.any((e) => e.titleId == titleId && e.mediaType == mediaType);
  }

  @override
  Future<void> remove({required int titleId, required String mediaType}) async {
    items.removeWhere((e) => e.titleId == titleId && e.mediaType == mediaType);
  }

  @override
  Stream<List<WatchlistEntry>> watchWatchlist({String? mediaType}) async* {
    yield await getWatchlist(mediaType: mediaType);
  }
}

