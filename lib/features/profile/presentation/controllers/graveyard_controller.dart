import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ranking/data/ranking_repository.dart';
import '../../data/graveyard_repository.dart';
import '../../domain/dropped_show.dart';

/// `SCR-18` state (FE-608). Dropping a title that is in the canon also removes it from the
/// canon through [RankingRepository.remove], which closes the rank gap and queues the delete.
class GraveyardController extends AsyncNotifier<List<DroppedShow>> {
  @override
  Future<List<DroppedShow>> build() => ref.watch(graveyardRepositoryProvider).fetchMine();

  Future<DroppedShow> drop({required int titleId, required String mediaType, required DropDetails details}) async {
    final saved =
        await ref.read(graveyardRepositoryProvider).drop(titleId: titleId, mediaType: mediaType, details: details);
    final rankings = ref.read(rankingRepositoryProvider);
    if ((await rankings.getCanon(mediaType)).any((r) => r.showId == titleId)) {
      await rankings.remove(mediaType: mediaType, titleId: titleId);
    }
    final current = state.valueOrNull ?? const <DroppedShow>[];
    state = AsyncData([
      saved,
      for (final s in current)
        if (!(s.titleId == titleId && s.mediaType == mediaType)) s,
    ]);
    return saved;
  }

  Future<void> setFlags(DroppedShow show, {bool? willingToRevisit, bool? notifyOnAcclaim}) async {
    final updated = show.copyWith(willingToRevisit: willingToRevisit, notifyOnAcclaim: notifyOnAcclaim);
    _replace(show, updated);
    try {
      await ref.read(graveyardRepositoryProvider).update(updated);
    } catch (_) {
      _replace(updated, show);
      rethrow;
    }
  }

  Future<void> resurrect(DroppedShow show) async {
    await ref.read(graveyardRepositoryProvider).remove(titleId: show.titleId, mediaType: show.mediaType);
    state = AsyncData([for (final s in state.valueOrNull ?? const <DroppedShow>[]) if (s.id != show.id) s]);
  }

  /// Forgets [show] locally. Revive deletes the server row in its own call (features/11 §4.7).
  void forget(DroppedShow show) =>
      state = AsyncData([for (final s in state.valueOrNull ?? const <DroppedShow>[]) if (s.id != show.id) s]);

  void _replace(DroppedShow from, DroppedShow to) =>
      state = AsyncData([for (final s in state.valueOrNull ?? const <DroppedShow>[]) s.id == from.id ? to : s]);
}

final graveyardControllerProvider =
    AsyncNotifierProvider<GraveyardController, List<DroppedShow>>(GraveyardController.new);
