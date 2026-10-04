import 'package:cached_network_image/cached_network_image.dart';
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

/// Whether posters load from the network. Widget tests override this to false: the
/// image cache never resolves there, so the shimmer would never settle.
final posterNetworkImagesProvider = Provider<bool>((ref) => true);

/// A cached poster with a shimmer placeholder and a readable [fallback] (FE-606).
class PosterImage extends ConsumerWidget {
  final String? posterPath;
  final Widget fallback;
  final BoxFit fit;

  const PosterImage({super.key, required this.posterPath, required this.fallback, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = TmdbImages.poster(posterPath);
    if (url == null || !ref.watch(posterNetworkImagesProvider)) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: TellyColors.backgroundSurface,
        highlightColor: TellyColors.backgroundCard,
        child: const ColoredBox(color: TellyColors.backgroundSurface),
      ),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
