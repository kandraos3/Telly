import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

/// User identity card and profile sub-header with cultural stats.
/// Conforms to `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §1, §2.
class ProfileHeaderCard extends StatelessWidget {
  final String displayName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final int movieCount;
  final int seriesCount;

  /// Opens Edit Profile (FE-PROFILE-02).
  final VoidCallback? onAvatarTap;

  const ProfileHeaderCard({
    super.key,
    required this.displayName,
    required this.handle,
    this.bio,
    this.avatarUrl,
    required this.movieCount,
    required this.seriesCount,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 1. AVATAR & NAME & BIO (the title and actions live in the screen's TellyScreenHeader)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar: tapping opens Edit Profile.
              Semantics(
                button: true,
                label: 'Edit profile',
                child: GestureDetector(
                  key: const Key('profile_avatar_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAvatarTap,
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TellyColors.cardOf(context),
                            border: Border.all(
                              color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.5),
                              width: 2.0,
                            ),
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl!.isNotEmpty
                                ? Image.network(
                                    avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _avatarFallback(),
                                  )
                                : _avatarFallback(),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TellyColors.primaryAccentOf(context),
                              border: Border.all(color: TellyColors.canvasOf(context), width: 2),
                            ),
                            child: Icon(Icons.edit_rounded, size: 12, color: Theme.of(context).brightness == Brightness.light ? Colors.white : TellyColors.backgroundPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Name and Bio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      key: const Key('profile_display_name_text'),
                      style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context)).copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (handle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        handle,
                        key: const Key('profile_handle_text'),
                        style: TellyTypography.bodyMedium(color: TellyColors.primaryAccentOf(context)).copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                    if (bio != null && bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bio!,
                        key: const Key('profile_bio_text'),
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. CULTURAL IDENTITY STATS ROW
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: TellyColors.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlassOf(context)),
            ),
            child: Text(
              '$movieCount Movies  •  $seriesCount Series',
              key: const Key('profile_stats_summary_text'),
              textAlign: TextAlign.center,
              style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return const Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: TellyColors.textTertiary,
        size: 36,
      ),
    );
  }
}
