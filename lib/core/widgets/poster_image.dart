import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/telly_colors.dart';

/// TMDB poster/backdrop URLs (`docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`).
abstract final class TmdbImages {
  static const base = 'https://image.tmdb.org/t/p';

  /// Full URL for a TMDB `poster_path` (e.g. `/abc.jpg`); passes absolute URLs through.
  static String? poster(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http') ? path : '$base/$size$path';
  }

  /// Full URL for a TMDB `backdrop_path` (e.g. `/abc.jpg`); passes absolute URLs through.
  static String? backdrop(String? path, {String size = 'w780'}) {
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http') ? path : '$base/$size$path';
  }
}

/// Whether posters load from the network. Defaults to false in test environments so
/// the shimmer animation never loops infinitely during pumpAndSettle.
final posterNetworkImagesProvider = Provider<bool>((ref) {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }
  return true;
});

/// A cached poster with a shimmer placeholder and a readable [fallback] (FE-606).
class PosterImage extends StatelessWidget {
  final String? posterPath;
  final Widget fallback;
  final BoxFit fit;

  const PosterImage({super.key, required this.posterPath, required this.fallback, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = TmdbImages.poster(posterPath);
    if (url == null) return fallback;

    bool enabled = !(!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      enabled = container.read(posterNetworkImagesProvider);
    } catch (_) {
      // Gracefully handles standalone widget tests without an ancestor ProviderScope
    }

    if (!enabled) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (ctx, __) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        final base = isLight ? const Color(0xFFE2E4EC) : TellyColors.backgroundSurface;
        final highlight = isLight ? const Color(0xFFF0F1F5) : TellyColors.backgroundCard;
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: ColoredBox(color: base),
        );
      },
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
