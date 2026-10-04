import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shares a 9:16 story asset through the OS share sheet.
abstract interface class StoryShareService {
  /// Shares a starter-canon story (features/01 Screen 5). [topTitles] are best first.
  Future<void> shareStarterCanon({required String canonLabel, required List<String> topTitles});
}

/// Thrown until the native share sheet lands (`DEV-601`, `share_plus`).
class StoryShareUnavailable implements Exception {
  const StoryShareUnavailable();

  @override
  String toString() => 'Story sharing is not available yet (DEV-601).';
}

class _UnavailableStoryShareService implements StoryShareService {
  const _UnavailableStoryShareService();

  @override
  Future<void> shareStarterCanon({required String canonLabel, required List<String> topTitles}) async =>
      throw const StoryShareUnavailable();
}

/// Replaced by the `share_plus` implementation in `DEV-601`.
final storyShareServiceProvider = Provider<StoryShareService>((ref) => const _UnavailableStoryShareService());
