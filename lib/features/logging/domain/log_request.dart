import 'title_search_result.dart';
import 'watch_status.dart';

/// What `/log` is opened with (features/11 §9.6): a title and, optionally, the watch status to
/// preselect. A bare [TitleSearchResult] extra still works.
class LogRequest {
  const LogRequest({required this.title, this.status});

  final TitleSearchResult title;

  /// Preselected on `SCR-09` when it is valid for the title's media type.
  final WatchStatus? status;
}
