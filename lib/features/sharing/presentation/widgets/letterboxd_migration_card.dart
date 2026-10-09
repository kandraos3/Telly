library letterboxd_migration_card;

import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';

/// Letterboxd Migration Celebration Card Generator.
/// Conforms to `FE-503` and `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §4.
class LetterboxdMigrationCard extends StatelessWidget {
  final int importedCount;
  final String topMovieTitle;
  final double topMovieScore;
  final String username;
  final String? posterPath;

  const LetterboxdMigrationCard({
    super.key,
    required this.importedCount,
    required this.topMovieTitle,
    this.topMovieScore = 10.00,
    required this.username,
    this.posterPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640, // 9:16 ratio preview
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Letterboxd to Telly badge
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3440), // Letterboxd slate
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('●●●', style: TextStyle(color: Color(0xFF00E054), fontSize: 10)),
                        SizedBox(width: 6),
                        Text(
                          'LETTERBOXD',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 14, color: TellyColors.textTertiaryOf(context)),
                  ),
                  TellyNeonBadge.winner(label: 'TELLY RANKINGS'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Imported $importedCount Films',
                style: TellyTypography.headlineSmall(
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'After pairwise sorting, here is my true #1:',
                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
              ),
            ],
          ),

          // Central Poster / Crown Card
          Container(
            width: 220,
            height: 320,
            decoration: BoxDecoration(
              color: TellyColors.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TellyColors.warmAmber.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: TellyColors.warmAmber.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_filter_outlined, size: 64, color: TellyColors.textTertiaryOf(context)),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            topMovieTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TellyTypography.titleLarge(
                              color: TellyColors.textPrimaryOf(context),
                            ).copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Crown #1 Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TellyColors.warmAmber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Text('👑', style: TextStyle(fontSize: 11)),
                          SizedBox(width: 4),
                          Text(
                            '#1 MOVIE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Score Tag
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TellyColors.phosphorLime.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        topMovieScore.toStringAsFixed(2),
                        style: TellyTypography.scoreHero(color: TellyColors.phosphorLime).copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Column(
            children: [
              Text(
                'Curated by @$username',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Compare your taste with me on telly.app/@$username',
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

