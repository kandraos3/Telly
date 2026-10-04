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
  final VoidCallback? onSettingsTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onSquadsTap;

  const ProfileHeaderCard({
    super.key,
    required this.displayName,
    required this.handle,
    this.bio,
    this.avatarUrl,
    required this.movieCount,
    required this.seriesCount,
    this.onSettingsTap,
    this.onShareTap,
    this.onSquadsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 1. TOP BAR: SETTINGS, HANDLE, SHARE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('profile_settings_button'),
                icon: const Icon(Icons.settings_outlined, color: TellyColors.textSecondary),
                onPressed: onSettingsTap,
              ),
              Text(
                handle,
                key: const Key('profile_handle_text'),
                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('profile_squads_button'),
                    tooltip: 'My Squads',
                    icon: const Icon(Icons.groups_2_outlined, color: TellyColors.textSecondary),
                    onPressed: onSquadsTap,
                  ),
                  IconButton(
                    key: const Key('profile_share_button'),
                    icon: const Icon(Icons.ios_share_rounded, color: TellyColors.textSecondary),
                    onPressed: onShareTap,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. AVATAR & NAME & BIO
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TellyColors.backgroundCard,
                  border: Border.all(
                    color: TellyColors.phosphorLime.withValues(alpha: 0.5),
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

              const SizedBox(width: 16),

              // Name and Bio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      key: const Key('profile_display_name_text'),
                      style: TellyTypography.titleLarge(color: TellyColors.textPrimary).copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (bio != null && bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bio!,
                        key: const Key('profile_bio_text'),
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. CULTURAL IDENTITY STATS ROW
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: TellyColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlass),
            ),
            child: Text(
              '$movieCount Movies  •  $seriesCount Series',
              key: const Key('profile_stats_summary_text'),
              textAlign: TextAlign.center,
              style: TellyTypography.caption(color: TellyColors.textSecondary).copyWith(
                fontWeight: FontWeight.w600,
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
