import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../domain/medal_story.dart';
import '../domain/reveal_story.dart';
import '../presentation/widgets/medal_story_card.dart';
import '../presentation/widgets/reveal_story_card.dart';
import '../presentation/widgets/story_card_renderer.dart';

/// Shares a 9:16 story asset through the OS share sheet (`DEV-601`, `share_plus`).
abstract interface class StoryShareService {
  /// Shares a starter-canon story (features/01 Screen 5). [topTitles] are best first.
  Future<void> shareStarterCanon({required String canonLabel, required List<String> topTitles});

  /// Renders the 1080×1920 rank-reveal story and opens the share sheet with it, where
  /// Instagram offers "Add to Story" (FE-SHARE-01).
  Future<void> shareRankReveal(RevealStory story);

  /// Renders the 1080×1920 medals story (one medal or a showcase, #138) and opens the share sheet.
  Future<void> shareMedals(MedalStory story);
}

/// Real implementation backed by `package:share_plus`.
class SharePlusStoryShareService implements StoryShareService {
  final Future<void> Function(ShareParams params) _share;
  final Future<Uint8List> Function(RevealStory story) _renderReveal;
  final Future<Uint8List> Function(MedalStory story) _renderMedals;
  final String shareUrl;

  SharePlusStoryShareService({
    Future<void> Function(ShareParams params)? share,
    Future<Uint8List> Function(RevealStory story)? renderReveal,
    Future<Uint8List> Function(MedalStory story)? renderMedals,
    this.shareUrl = kDefaultShareUrl,
  })  : _share = share ?? ((params) => SharePlus.instance.share(params)),
        _renderReveal = renderReveal ?? ((story) => StoryCardRenderer.renderOffscreen(RevealStoryCard(story: story))),
        _renderMedals = renderMedals ?? ((story) => StoryCardRenderer.renderOffscreen(MedalStoryCard(story: story)));

  @override
  Future<void> shareStarterCanon({
    required String canonLabel,
    required List<String> topTitles,
  }) async {
    final buffer = StringBuffer('🎬 My $canonLabel on Telly:\n\n');
    for (var i = 0; i < topTitles.length; i++) {
      buffer.writeln('#${i + 1} ${topTitles[i]}');
    }
    buffer.writeln('\nRank your own favorites on Telly: $shareUrl');
    await _share(ShareParams(text: buffer.toString(), subject: 'My $canonLabel Top Shows'));
  }

  @override
  Future<void> shareRankReveal(RevealStory story) async {
    final png = await _renderReveal(story);
    await _share(ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'telly_story.png')],
      fileNameOverrides: const ['telly_story.png'],
      text: story.caption,
    ));
  }

  @override
  Future<void> shareMedals(MedalStory story) async {
    final png = await _renderMedals(story);
    await _share(ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'telly_medals.png')],
      fileNameOverrides: const ['telly_medals.png'],
      text: '${story.caption} $shareUrl',
    ));
  }
}

/// In-memory fake for widget and unit tests (zero platform channel calls).
class FakeStoryShareService implements StoryShareService {
  final List<({String canonLabel, List<String> topTitles})> sharedStories = [];
  final List<RevealStory> sharedReveals = [];
  final List<MedalStory> sharedMedals = [];

  @override
  Future<void> shareStarterCanon({
    required String canonLabel,
    required List<String> topTitles,
  }) async {
    sharedStories.add((canonLabel: canonLabel, topTitles: List.unmodifiable(topTitles)));
  }

  @override
  Future<void> shareRankReveal(RevealStory story) async => sharedReveals.add(story);

  @override
  Future<void> shareMedals(MedalStory story) async => sharedMedals.add(story);
}

final storyShareServiceProvider = Provider<StoryShareService>(
    (ref) => SharePlusStoryShareService(shareUrl: ref.watch(appConfigProvider).shareUrl));
