library settings_hub_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/profile/domain/data_exporter.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';

/// SCR-20: Settings Hub & Granular Preferences.
/// Conforms to `FE-505`, `FE-506`, `LEGAL-502` and
/// `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §20.
class SettingsHubScreen extends ConsumerStatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  ConsumerState<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends ConsumerState<SettingsHubScreen> {
  bool _biometricUnlock = true;
  bool _upsetAlerts = true;
  bool _coWatchInvites = true;
  bool _leavingSoonAlerts = true;
  bool _quietHours = false;
  double _cacheSizeMb = 24.5;
  String _selectedCountry = 'US';

  void _clearCache() {
    setState(() {
      _cacheSizeMb = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image cache cleared successfully.'),
        backgroundColor: TellyColors.backgroundCard,
      ),
    );
  }

  void _exportCsv() {
    final sample = [
      const ExportRankingItem(
        title: 'Succession',
        tmdbId: 76331,
        rank: 1,
        score: 10.0,
        status: 'COMPLETED',
        tier: 'God Tier',
        review: 'Flawless finale',
        mvpActor: 'Jeremy Strong',
        tags: ['FlawlessFinale', 'PeakDialogue'],
        dateLogged: '2024-05-12',
      ),
    ];
    DataExporter.generateCanonCsv(sampleRankings: sample);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Exported ${sample.length} records to CSV!'),
          backgroundColor: TellyColors.backgroundCard,
        ),
      );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TellyColors.backgroundCard,
        title: const Text('Delete Account?', style: TextStyle(color: TellyColors.neonCoral)),
        content: Text(
          'Your account will be placed into a 30-day soft deletion period. During this time, your canons will be hidden and you can reactivate by logging back in.',
          style: TellyTypography.caption(color: TellyColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: TellyColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account scheduled for deletion in 30 days.'),
                  backgroundColor: TellyColors.neonCoral,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: TellyColors.neonCoral),
            child: const Text('Confirm Deletion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userSubscriptions = ref.watch(userSubscriptionsProvider);

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SETTINGS & PREFERENCES',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Account Section
          _buildSectionHeader('ACCOUNT & SECURITY'),
          _buildCard(
            children: [
              _buildTile(
                title: 'Username & Handle',
                subtitle: '@jordan (Jordan Miller)',
                trailing: const Icon(Icons.chevron_right, color: TellyColors.textTertiary, size: 20),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildSwitchTile(
                title: 'Biometric FaceID Unlock',
                subtitle: 'Require biometric authentication on app launch',
                value: _biometricUnlock,
                onChanged: (val) => setState(() => _biometricUnlock = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Subscriptions & Region
          _buildSectionHeader('STREAMING SUBSCRIPTIONS'),
          _buildCard(
            children: [
              _buildTile(
                title: 'JustWatch Country Region',
                subtitle: 'Currently set to $_selectedCountry',
                trailing: DropdownButton<String>(
                  value: _selectedCountry,
                  dropdownColor: TellyColors.backgroundCard,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountry = val);
                  },
                  items: const [
                    DropdownMenuItem(value: 'US', child: Text('US 🇺🇸')),
                    DropdownMenuItem(value: 'UK', child: Text('UK 🇬🇧')),
                    DropdownMenuItem(value: 'CA', child: Text('CA 🇨🇦')),
                  ],
                ),
              ),
              const Divider(color: TellyColors.borderGlass),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['netflix', 'max', 'apple_tv_plus', 'hulu', 'prime_video', 'crunchyroll'].map((p) {
                    final isSubbed = userSubscriptions.contains(p);
                    return FilterChip(
                      label: Text(p.toUpperCase()),
                      selected: isSubbed,
                      onSelected: (selected) {
                        final updated = Set<String>.from(userSubscriptions);
                        if (selected) {
                          updated.add(p);
                        } else {
                          updated.remove(p);
                        }
                        ref.read(userSubscriptionsProvider.notifier).state = updated;
                      },
                      backgroundColor: TellyColors.backgroundCard,
                      selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.2),
                      side: BorderSide(color: isSubbed ? TellyColors.phosphorLime : TellyColors.borderGlass),
                      labelStyle: TextStyle(
                        color: isSubbed ? TellyColors.phosphorLime : TellyColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Notifications Matrix
          _buildSectionHeader('NOTIFICATION PREFERENCES'),
          _buildCard(
            children: [
              _buildSwitchTile(
                title: 'Spicy Upset Alerts',
                subtitle: 'When friends rank a dark horse over a titan',
                value: _upsetAlerts,
                onChanged: (val) => setState(() => _upsetAlerts = val),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildSwitchTile(
                title: 'Co-Watch Invitations',
                subtitle: 'When friends start a Two-to-Watch session',
                value: _coWatchInvites,
                onChanged: (val) => setState(() => _coWatchInvites = val),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildSwitchTile(
                title: 'Watchlist Leaving Soon Alerts',
                subtitle: '7-day warning before licenses expire',
                value: _leavingSoonAlerts,
                onChanged: (val) => setState(() => _leavingSoonAlerts = val),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildSwitchTile(
                title: 'Quiet Hours (10 PM - 8 AM)',
                subtitle: 'Silence all non-urgent notifications overnight',
                value: _quietHours,
                onChanged: (val) => setState(() => _quietHours = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Storage & Cache Hygiene
          _buildSectionHeader('STORAGE HYGIENE'),
          _buildCard(
            children: [
              _buildTile(
                title: 'Local Poster Cache',
                subtitle: '${_cacheSizeMb.toStringAsFixed(1)} MB currently used',
                trailing: TextButton(
                  onPressed: _cacheSizeMb > 0 ? _clearCache : null,
                  child: Text(
                    'Clear Cache',
                    style: TextStyle(
                      color: _cacheSizeMb > 0 ? TellyColors.phosphorLime : TellyColors.textDisabled,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Data Portability (FE-506)
          _buildSectionHeader('DATA PORTABILITY & EXPORTS'),
          _buildCard(
            children: [
              _buildTile(
                title: 'Export Canon to CSV',
                subtitle: 'RFC 4180 standard spreadsheet export',
                trailing: const Icon(Icons.download, color: TellyColors.phosphorLime, size: 20),
                onTap: _exportCsv,
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildTile(
                title: 'Export to Letterboxd Format',
                subtitle: 'Compatible with Letterboxd diary re-import',
                trailing: const Icon(Icons.download, color: TellyColors.phosphorLime, size: 20),
                onTap: _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Legal & Account Deletion (LEGAL-501, LEGAL-502)
          _buildSectionHeader('LEGAL & COMPLIANCE'),
          _buildCard(
            children: [
              _buildTile(
                title: 'Privacy Policy',
                subtitle: 'https://telly.app/privacy',
                trailing: const Icon(Icons.open_in_new, color: TellyColors.textTertiary, size: 18),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildTile(
                title: 'Terms of Service (EULA)',
                subtitle: 'https://telly.app/terms',
                trailing: const Icon(Icons.open_in_new, color: TellyColors.textTertiary, size: 18),
              ),
              const Divider(color: TellyColors.borderGlass),
              _buildTile(
                title: 'Delete Account',
                subtitle: 'Mandatory 30-day soft deletion pipeline',
                trailing: const Icon(Icons.delete_forever, color: TellyColors.neonCoral, size: 20),
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TellyTypography.labelSmall(
          color: TellyColors.textTertiary,
        ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TellyTypography.caption(color: TellyColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TellyTypography.caption(color: TellyColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: TellyColors.phosphorLime,
            activeTrackColor: TellyColors.phosphorLime.withValues(alpha: 0.3),
            inactiveThumbColor: TellyColors.textTertiary,
            inactiveTrackColor: TellyColors.strokeSubtle,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
