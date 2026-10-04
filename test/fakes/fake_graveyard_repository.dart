import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';

/// In-memory [GraveyardRepository] (FE-608).
class FakeGraveyardRepository implements GraveyardRepository {
  final shows = <DroppedShow>[];
  bool failReads = false;
  bool failWrites = false;
  final updates = <DroppedShow>[];

  @override
  Future<List<DroppedShow>> fetchMine() async {
    if (failReads) throw Exception('offline');
    return List.of(shows);
  }

  @override
  Future<DroppedShow> drop({required int titleId, required String mediaType, required DropDetails details}) async {
    if (failWrites) throw Exception('rejected');
    final show = DroppedShow(
      id: 'drop-$titleId',
      userId: 'u1',
      titleId: titleId,
      mediaType: mediaType,
      title: 'Title $titleId',
      releaseYear: 2020,
      droppedAtSeason: details.season,
      droppedAtEpisode: details.episode,
      reason: details.reason,
      createdAt: DateTime(2026, 10, 3),
    );
    shows.add(show);
    return show;
  }

  @override
  Future<void> update(DroppedShow show) async {
    if (failWrites) throw Exception('rejected');
    updates.add(show);
  }

  @override
  Future<void> remove({required int titleId, required String mediaType}) async =>
      shows.removeWhere((s) => s.titleId == titleId && s.mediaType == mediaType);
}
