import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/data/canon_import_service.dart';
import '../../../onboarding/domain/anilist_importer.dart';
import '../../../onboarding/domain/letterboxd_csv_parser.dart';

enum ImportSource {
  letterboxd('Letterboxd'),
  aniList('AniList');

  final String label;
  const ImportSource(this.label);
}

/// Settings → Import Watch History (FE-SETTINGS-02).
sealed class WatchHistoryImportState {
  const WatchHistoryImportState();
}

class ImportIdle extends WatchHistoryImportState {
  const ImportIdle();
}

class ImportRunning extends WatchHistoryImportState {
  const ImportRunning(this.source);
  final ImportSource source;
}

class ImportDone extends WatchHistoryImportState {
  const ImportDone(this.source, this.result);
  final ImportSource source;
  final ImportResult result;
}

class ImportFailed extends WatchHistoryImportState {
  const ImportFailed(this.source, this.message);
  final ImportSource source;
  final String message;
}

/// Runs a Letterboxd CSV or AniList import into my canons through the same
/// [CanonImportService] onboarding uses. Titles already ranked are skipped, so
/// importing twice is safe. Not auto-disposed: an import keeps going if I leave Settings.
class WatchHistoryImportController extends Notifier<WatchHistoryImportState> {
  @override
  WatchHistoryImportState build() => const ImportIdle();

  bool get isRunning => state is ImportRunning;

  Future<void> importLetterboxd(String csv) async {
    if (isRunning) return;
    if (LetterboxdCsvParser.parse(csv).isEmpty) {
      state = const ImportFailed(
        ImportSource.letterboxd,
        'No films found in that file. Pick watched.csv or ratings.csv from your Letterboxd export.',
      );
      return;
    }
    await _run(ImportSource.letterboxd, () => ref.read(canonImportServiceProvider).importLetterboxd(csv));
  }

  Future<void> importAniList(String username) async {
    final name = username.trim().replaceFirst('@', '');
    if (isRunning || name.isEmpty) return;
    await _run(ImportSource.aniList, () async {
      final entries = await ref.read(aniListImporterProvider).fetchUserAnime(name);
      return ref.read(canonImportServiceProvider).importAniList(entries);
    });
  }

  void dismiss() => state = const ImportIdle();

  Future<void> _run(ImportSource source, Future<ImportResult> Function() run) async {
    state = ImportRunning(source);
    try {
      state = ImportDone(source, await run());
    } on AniListUserNotFoundException catch (e) {
      state = ImportFailed(source, 'No AniList profile found for @${e.username}.');
    } catch (_) {
      state = ImportFailed(source, "Couldn't finish the ${source.label} import. Check your connection and try again.");
    }
  }
}

final watchHistoryImportProvider =
    NotifierProvider<WatchHistoryImportController, WatchHistoryImportState>(WatchHistoryImportController.new);
