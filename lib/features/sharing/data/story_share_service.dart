import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a 9:16 story asset through the OS share sheet (`DEV-601`, `share_plus`).
abstract interface class StoryShareService {
  /// Shares a starter-canon story (features/01 Screen 5). [topTitles] are best first.
  Future<void> shareStarterCanon({required String canonLabel, required List<String> topTitles});
}

/// Real implementation backed by `package:share_plus`.
class SharePlusStoryShareService implements StoryShareService {
  final Future<void> Function(String text, {String? subject}) _shareText;

  SharePlusStoryShareService({
    Future<void> Function(String text, {String? subject})? shareText,
  }) : _shareText = shareText ??
            ((text, {subject}) => SharePlus.instance
                .share(ShareParams(text: text, subject: subject)));

  @override
  Future<void> shareStarterCanon({
    required String canonLabel,
    required List<String> topTitles,
  }) async {
    final buffer = StringBuffer('🎬 My $canonLabel on Telly:\n\n');
    for (var i = 0; i < topTitles.length; i++) {
      buffer.writeln('#${i + 1} ${topTitles[i]}');
    }
    buffer.writeln('\nRank your own favorites on Telly: https://telly.app');
    await _shareText(buffer.toString(), subject: 'My $canonLabel Top Shows');
  }
}

/// In-memory fake for widget and unit tests (zero platform channel calls).
class FakeStoryShareService implements StoryShareService {
  final List<({String canonLabel, List<String> topTitles})> sharedStories = [];

  @override
  Future<void> shareStarterCanon({
    required String canonLabel,
    required List<String> topTitles,
  }) async {
    sharedStories.add((canonLabel: canonLabel, topTitles: List.unmodifiable(topTitles)));
  }
}

final storyShareServiceProvider = Provider<StoryShareService>((ref) => SharePlusStoryShareService());

