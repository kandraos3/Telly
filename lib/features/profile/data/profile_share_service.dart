import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';

/// Shares the signed-in user's profile through the OS share sheet (FE-PROFILE-02).
///
/// Until the telly.app profile pages are hosted the message carries the handle (findable
/// in Explore search) and [shareUrl], the store listing by default.
class ProfileShareService {
  ProfileShareService({
    Future<void> Function(ShareParams params)? share,
    this.shareUrl = kDefaultShareUrl,
  }) : _share = share ?? ((params) => SharePlus.instance.share(params));

  final Future<void> Function(ShareParams params) _share;
  final String shareUrl;

  /// Builds the share caption: the handle, then up to three top titles from each canon.
  static String caption({
    required String handle,
    required String displayName,
    List<String> topMovies = const [],
    List<String> topSeries = const [],
    required String shareUrl,
  }) {
    final who = displayName.isEmpty ? '@$handle' : '$displayName (@$handle)';
    final buffer = StringBuffer('Check out $who on Telly.\n');
    void section(String label, List<String> titles) {
      if (titles.isEmpty) return;
      buffer.writeln('\n$label');
      for (var i = 0; i < titles.length && i < 3; i++) {
        buffer.writeln('${i + 1}. ${titles[i]}');
      }
    }

    section('Top movies', topMovies);
    section('Top TV shows', topSeries);
    buffer.write('\nFind @$handle in Telly: $shareUrl');
    return buffer.toString();
  }

  Future<void> shareProfile({
    required String handle,
    required String displayName,
    List<String> topMovies = const [],
    List<String> topSeries = const [],
  }) {
    return _share(ShareParams(
      subject: 'My rankings on Telly',
      text: caption(
        handle: handle,
        displayName: displayName,
        topMovies: topMovies,
        topSeries: topSeries,
        shareUrl: shareUrl,
      ),
    ));
  }
}

final profileShareServiceProvider = Provider<ProfileShareService>(
    (ref) => ProfileShareService(shareUrl: ref.watch(appConfigProvider).shareUrl));
