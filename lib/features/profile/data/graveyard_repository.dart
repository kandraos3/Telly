import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../../core/widgets/poster_image.dart';
import '../domain/dropped_show.dart';

/// `SCR-18` TV Graveyard ↔ `user_dropped_shows` (features/03 §2, FE-608).
abstract interface class GraveyardRepository {
  Future<List<DroppedShow>> fetchMine();

  /// Upserts the drop for a title (one row per title).
  Future<DroppedShow> drop({required int titleId, required String mediaType, required DropDetails details});

  Future<void> update(DroppedShow show);

  /// "Resurrect": removes the title from the Graveyard.
  Future<void> remove({required int titleId, required String mediaType});
}

class SupabaseGraveyardRepository implements GraveyardRepository {
  SupabaseGraveyardRepository(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  String get _me => _currentUserId() ?? (throw StateError('Not signed in'));

  static const _columns = 'id, user_id, title_id, media_type, dropped_at_season, dropped_at_episode, reason, '
      'willing_to_revisit, notify_on_acclaim, notes, created_at, titles(title, poster_path, release_date)';

  @override
  Future<List<DroppedShow>> fetchMine() async {
    final rows = await _client
        .from('user_dropped_shows')
        .select(_columns)
        .eq('user_id', _me)
        .order('created_at', ascending: false);
    return [for (final r in rows) fromRow(r)];
  }

  @override
  Future<DroppedShow> drop({required int titleId, required String mediaType, required DropDetails details}) async {
    final row = await _client
        .from('user_dropped_shows')
        .upsert({
          'user_id': _me,
          'title_id': titleId,
          'media_type': mediaType,
          'dropped_at_season': details.season,
          'dropped_at_episode': details.episode,
          'reason': DropReasonTaxonomy.toDbValue(details.reason),
          'willing_to_revisit': details.willingToRevisit,
          'notify_on_acclaim': details.notifyOnAcclaim,
          'notes': details.notes,
        }, onConflict: 'user_id,title_id,media_type')
        .select(_columns)
        .single();
    return fromRow(row);
  }

  @override
  Future<void> update(DroppedShow show) => _client.from('user_dropped_shows').update({
        'willing_to_revisit': show.willingToRevisit,
        'notify_on_acclaim': show.notifyOnAcclaim,
        'notes': show.notes,
      }).eq('id', show.id);

  @override
  Future<void> remove({required int titleId, required String mediaType}) => _client
      .from('user_dropped_shows')
      .delete()
      .eq('user_id', _me)
      .eq('title_id', titleId)
      .eq('media_type', mediaType);

  static DroppedShow fromRow(Map<String, dynamic> r) {
    final title = (r['titles'] as Map?) ?? const {};
    final released = title['release_date'] as String?;
    return DroppedShow(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      titleId: (r['title_id'] as num).toInt(),
      mediaType: r['media_type'] as String,
      title: (title['title'] as String?) ?? 'Untitled',
      posterUrl: TmdbImages.poster(title['poster_path'] as String?),
      releaseYear: released == null || released.length < 4 ? 0 : int.parse(released.substring(0, 4)),
      droppedAtSeason: (r['dropped_at_season'] as num?)?.toInt() ?? 1,
      droppedAtEpisode: (r['dropped_at_episode'] as num?)?.toInt(),
      reason: DropReasonTaxonomy.fromDbValue(r['reason'] as String?) ?? DropReasonTaxonomy.betterOptions,
      willingToRevisit: (r['willing_to_revisit'] as bool?) ?? false,
      notifyOnAcclaim: (r['notify_on_acclaim'] as bool?) ?? false,
      notes: r['notes'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    );
  }
}

final graveyardRepositoryProvider =
    Provider<GraveyardRepository>((ref) => SupabaseGraveyardRepository(ref.watch(supabaseClientProvider)));
