import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ranking/data/ranking_repository.dart';
import '../../ranking/domain/canon_tier.dart';
import '../domain/data_exporter.dart';

/// Poster/artwork cache (settings spec S5, FE-608).
abstract interface class ImageCacheService {
  /// Bytes used by cached artwork on disk.
  Future<int> sizeBytes();

  Future<void> clear();
}

class DefaultImageCacheService implements ImageCacheService {
  @override
  Future<int> sizeBytes() async {
    // flutter_cache_manager's default store lives in <temp>/libCachedImageData.
    final dir = Directory(p.join((await getTemporaryDirectory()).path, DefaultCacheManager.key));
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final f in dir.list(recursive: true, followLinks: false)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  @override
  Future<void> clear() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}

final imageCacheServiceProvider = Provider<ImageCacheService>((ref) => DefaultImageCacheService());

/// Hands a generated file to the OS share sheet.
typedef ShareFile = Future<void> Function({required String path, required String mimeType, required String subject});

Future<void> _shareWithSheet({required String path, required String mimeType, required String subject}) =>
    SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: mimeType)], subject: subject));

final shareFileProvider = Provider<ShareFile>((ref) => _shareWithSheet);

/// "Export My TV Canon" (settings spec S1, legacy FE-506): both canons as one CSV built
/// from the local canon, written to a temp file and offered through the share sheet.
class CanonExportService {
  CanonExportService(this._rankings, this._share, {Future<Directory> Function()? tempDir})
      : _tempDir = tempDir ?? getTemporaryDirectory;

  final RankingRepository _rankings;
  final ShareFile _share;
  final Future<Directory> Function() _tempDir;

  /// Returns the number of exported rows.
  Future<int> exportCsv() async {
    final items = <ExportRankingItem>[
      for (final mediaType in const ['movie', 'tv'])
        for (final r in await _rankings.getCanon(mediaType))
          ExportRankingItem(
            title: r.title,
            tmdbId: r.showId,
            rank: r.rankPosition,
            score: r.calculatedScore,
            tier: CanonTier.fromScore(r.calculatedScore).label,
            mvpActor: r.favoriteCharacter,
            dateLogged: r.updatedAt.toIso8601String().substring(0, 10),
            mediaType: mediaType,
          ),
    ];
    final file = File(p.join((await _tempDir()).path, 'telly_canon_export.csv'));
    await file.writeAsString(DataExporter.generateCanonCsv(items: items));
    await _share(path: file.path, mimeType: 'text/csv', subject: 'My Telly canon');
    return items.length;
  }

  /// Movie canon in Letterboxd's import format (films only: Letterboxd has no tv).
  Future<int> exportLetterboxd() async {
    final movies = [
      for (final r in await _rankings.getCanon('movie'))
        ExportRankingItem(
          title: r.title,
          tmdbId: r.showId,
          rank: r.rankPosition,
          score: r.calculatedScore,
          dateLogged: r.updatedAt.toIso8601String().substring(0, 10),
          mediaType: 'movie',
        ),
    ];
    final file = File(p.join((await _tempDir()).path, 'telly_letterboxd_import.csv'));
    await file.writeAsString(DataExporter.generateLetterboxdCsv(items: movies));
    await _share(path: file.path, mimeType: 'text/csv', subject: 'Telly → Letterboxd import');
    return movies.length;
  }
}

final canonExportServiceProvider = Provider<CanonExportService>(
  (ref) => CanonExportService(ref.watch(rankingRepositoryProvider), ref.watch(shareFileProvider)),
);
