import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

/// Card widget representing a duel candidate in SCR-10 Binary Duel Arena.
/// Conforms to `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §4
/// and `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §10.
class DuelArenaCard extends StatelessWidget {
  final int showId;
  final String title;
  final String? subtitle;
  final String? posterPath;
  final String actionPrompt;
  final bool isWinner;
  final bool isLoser;
  final VoidCallback? onTap;

  const DuelArenaCard({
    super.key,
    required this.showId,
    required this.title,
    this.subtitle,
    this.posterPath,
    required this.actionPrompt,
    this.isWinner = false,
    this.isLoser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isWinner
        ? TellyColors.phosphorLime
        : isLoser
            ? Colors.transparent
            : TellyColors.borderGlass;

    final double targetOpacity = isLoser ? 0.20 : 1.0;
    final double targetScale = isWinner ? 1.04 : (isLoser ? 0.96 : 1.0);

    return AnimatedScale(
      scale: targetScale,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: targetOpacity,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: TellyColors.phosphorLime.withValues(alpha: 0.15),
            highlightColor: TellyColors.phosphorLime.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TellyColors.backgroundCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                  width: isWinner ? 2.0 : 1.0,
                ),
                boxShadow: isWinner
                    ? [
                        BoxShadow(
                          color: TellyColors.phosphorLime.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Poster Thumbnail (2:3 aspect ratio)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 108,
                      color: TellyColors.backgroundSurface,
                      child: posterPath != null && posterPath!.isNotEmpty
                          ? Image.network(
                              posterPath!.startsWith('http')
                                  ? posterPath!
                                  : 'https://image.tmdb.org/t/p/w300$posterPath',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
                            )
                          : _buildPosterPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title & Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TellyTypography.titleMedium(
                            color: TellyColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            style: TellyTypography.bodyMedium(
                              color: TellyColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Action prompt hint
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 14,
                              color: isWinner
                                  ? TellyColors.phosphorLime
                                  : TellyColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              actionPrompt,
                              style: TellyTypography.caption(
                                color: isWinner
                                    ? TellyColors.phosphorLime
                                    : TellyColors.textTertiary,
                              ).copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        color: TellyColors.textTertiary,
        size: 32,
      ),
    );
  }
}
