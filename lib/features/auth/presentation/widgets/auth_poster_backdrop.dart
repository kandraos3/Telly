import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../onboarding/data/top_50_seeds.dart';

/// SCR-01 ambient backdrop: a tilted mosaic of prestige-TV posters dimmed by a
/// Void Canvas scrim (80%) so foreground text keeps WCAG AA contrast.
class AuthPosterBackdrop extends StatelessWidget {
  static const columns = 4;
  static const rows = 6;
  static const scrimOpacity = 0.8;

  const AuthPosterBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final posters = kTop50SeedTitles.map((t) => t.posterPath).toList();
    // Oversize the grid so the rotated mosaic still covers the corners.
    final tileWidth = MediaQuery.sizeOf(context).width * 1.4 / columns;

    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: TellyColors.backgroundPrimary),
          ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: -8 * math.pi / 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < rows; r++)
                      Transform.translate(
                        offset: Offset(r.isOdd ? -tileWidth / 3 : 0, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var c = 0; c < columns; c++)
                              _PosterTile(
                                key: ValueKey('auth-backdrop-poster-$r-$c'),
                                posterPath: posters[(r * columns + c) % posters.length],
                                width: tileWidth,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Uniform 80% scrim, deepening to solid at the button stack.
          DecoratedBox(
            key: const ValueKey('auth-backdrop-scrim'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  TellyColors.backgroundPrimary.withValues(alpha: scrimOpacity),
                  TellyColors.backgroundPrimary.withValues(alpha: 0.88),
                  TellyColors.backgroundPrimary,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  final String posterPath;
  final double width;

  const _PosterTile({super.key, required this.posterPath, required this.width});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width - 8,
          height: (width - 8) * 1.5,
          child: PosterImage(
            posterPath: posterPath,
            fallback: const ColoredBox(color: TellyColors.backgroundSurface),
          ),
        ),
      ),
    );
  }
}
