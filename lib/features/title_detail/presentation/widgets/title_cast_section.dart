import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../data/title_detail_repository.dart';

/// SCR-08 "Cast & Crew": live TMDB credits with actor photos and character names, the
/// director (movies) or creators (series) as a chip (BE-DETAIL-01).
class TitleCastSection extends ConsumerWidget {
  static const emptyMessage = 'No cast information is available for this title yet.';

  final int titleId;
  final String mediaType;

  /// Shown until credits arrive (and kept if TMDB has no director).
  final String? fallbackDirector;

  const TitleCastSection({super.key, required this.titleId, required this.mediaType, this.fallbackDirector});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(titleCreditsProvider((titleId, mediaType)));
    final value = credits.valueOrNull;
    final isMovie = mediaType == 'movie';
    final leads = isMovie
        ? [if ((value?.director ?? fallbackDirector)?.isNotEmpty ?? false) value?.director ?? fallbackDirector!]
        : (value?.creators.isNotEmpty ?? false)
            ? value!.creators
            : [if (fallbackDirector?.isNotEmpty ?? false) fallbackDirector!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(color: TellyColors.warmAmber, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              'CAST & CREW',
              style: TellyTypography.labelSmall(color: TellyColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            if (leads.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    key: const Key('title_cast_lead_chip'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TellyColors.borderGlass),
                    ),
                    child: Text(
                      '${isMovie ? 'Dir' : (leads.length > 1 ? 'Showrunners' : 'Showrunner')}: ${leads.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TellyTypography.caption(color: TellyColors.warmAmber).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        switch (credits) {
          AsyncData(:final value) when value.members.isNotEmpty => SizedBox(
              height: 148,
              child: ListView.separated(
                key: const Key('title_cast_carousel'),
                scrollDirection: Axis.horizontal,
                itemCount: value.members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _CastCard(member: value.members[i]),
              ),
            ),
          AsyncLoading() => const SizedBox(
              height: 148,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: TellyColors.phosphorLime)),
            ),
          _ => Container(
              key: const Key('title_cast_empty'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TellyColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlass),
              ),
              child: Text(emptyMessage, style: TellyTypography.caption(color: TellyColors.textPrimary)),
            ),
        },
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  final TitleCastMember member;

  const _CastCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 72,
              child: PosterImage(
                posterPath: member.profilePath,
                fallback: ColoredBox(
                  color: TellyColors.backgroundCard,
                  child: Center(
                    child: Text(
                      member.name.isEmpty ? '?' : member.name.characters.first.toUpperCase(),
                      style: TellyTypography.titleLarge(color: TellyColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TellyTypography.labelMedium(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          if (member.character.isNotEmpty)
            Text(
              member.character,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TellyTypography.caption(color: TellyColors.textSecondary).copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
