library settings_hub_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/biometrics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../onboarding/presentation/screens/streaming_setup_screen.dart';
import '../../data/profile_repository.dart';
import '../../data/settings_services.dart';
import '../controllers/settings_controllers.dart';

/// Disk usage of cached artwork (settings spec S5).
final imageCacheSizeProvider =
    FutureProvider.autoDispose<int>((ref) => ref.watch(imageCacheServiceProvider).sizeBytes());

/// SCR-20: Settings Hub & Granular Preferences.
/// Conforms to `docs/adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md` and
/// `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §20.
/// FE-608: every control reads and writes persisted state — `users.preferences`
/// ([preferencesProvider]), `user_streaming_subscriptions` ([subscriptionsProvider]),
/// the profile's visibility, the artwork cache and the canon export.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  Future<void> _guard(BuildContext context, Future<void> Function() action, {String? success}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't save that. Check your connection.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider.select((s) => s.user));
    final prefsAsync = ref.watch(preferencesProvider);
    final prefs = prefsAsync.valueOrNull ?? const AppPreferences();
    final prefsController = ref.read(preferencesProvider.notifier);
    final subs = ref.watch(subscriptionsProvider).valueOrNull;
    final cacheSize = ref.watch(imageCacheSizeProvider);

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.canon),
        ),
        title: Text(
          'SETTINGS & PREFERENCES',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          if (prefsAsync.hasError)
            Padding(
              key: const Key('settings_prefs_error'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text("Couldn't load your preferences; showing defaults.",
                        style: TellyTypography.caption(color: TellyColors.warmAmber)),
                  ),
                  TextButton(onPressed: () => ref.invalidate(preferencesProvider), child: const Text('Retry')),
                ],
              ),
            ),

          // 1. Account
          const _SectionHeader('ACCOUNT'),
          _Card(children: [
            _Tile(
              key: const Key('settings_edit_profile'),
              title: me?.displayName.isNotEmpty == true ? me!.displayName : 'Your profile',
              subtitle: me?.username == null ? 'Edit Profile & Showcases' : '@${me!.username} • Edit Profile & Showcases',
              trailing: const Icon(Icons.chevron_right, color: TellyColors.textTertiary, size: 20),
              onTap: () => context.push(Routes.editProfile),
            ),
            const Divider(color: TellyColors.borderGlass),
            _VisibilityTile(current: me?.visibilityMode ?? 'PUBLIC'),
            const Divider(color: TellyColors.borderGlass),
            _SwitchTile(
              key: const Key('settings_biometric_unlock'),
              title: 'Biometric Quick Unlock',
              subtitle: 'Face ID / Fingerprint to unlock app (auth §4.1)',
              value: prefs.biometricEnabled,
              onChanged: (on) async {
                if (on) {
                  final can = await ref.read(biometricsServiceProvider).canAuthenticate();
                  if (!can) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric authentication is not supported or not enrolled on this device.')),
                      );
                    }
                    return;
                  }
                  final ok = await ref.read(biometricsServiceProvider).authenticate(
                        localizedReason: 'Authenticate to enable biometric quick unlock',
                      );
                  if (!ok) return;
                }
                if (context.mounted) {
                  _guard(context, () => prefsController.edit((p) => p.copyWith(biometricEnabled: on)));
                }
              },
            ),
          ]),
          const SizedBox(height: 20),

          // 2. Streaming subscriptions & region (S2)
          const _SectionHeader('STREAMING SUBSCRIPTIONS'),
          _Card(children: [
            _Tile(
              title: 'Country / Region',
              subtitle: 'Localized catalog for availability badges',
              trailing: DropdownButton<String>(
                key: const Key('settings_region'),
                value: prefs.region,
                dropdownColor: TellyColors.backgroundCard,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold),
                onChanged: (v) => v == null ? null : _guard(context, () => prefsController.edit((p) => p.copyWith(region: v))),
                items: [for (final r in AppPreferences.regions) DropdownMenuItem(value: r, child: Text(r))],
              ),
            ),
            const Divider(color: TellyColors.borderGlass),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final provider in kDefaultStreamingProviders)
                    FilterChip(
                      key: Key('settings_sub_${provider.id}'),
                      label: Text(provider.name),
                      selected: subs?.platformIds.contains(provider.id) ?? false,
                      onSelected: subs == null
                          ? null
                          : (on) => _guard(
                                context,
                                () => ref.read(subscriptionsProvider.notifier).save(
                                      on
                                          ? {...subs.platformIds, provider.id}
                                          : ({...subs.platformIds}..remove(provider.id)),
                                    ),
                              ),
                      backgroundColor: TellyColors.backgroundCard,
                      selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            const Divider(color: TellyColors.borderGlass),
            _SwitchTile(
              key: const Key('settings_include_free'),
              title: 'Include free services',
              subtitle: 'Tubi, Pluto, Kanopy',
              value: subs?.includeFreePlatforms ?? false,
              onChanged: (v) => subs == null
                  ? null
                  : _guard(context, () => ref.read(subscriptionsProvider.notifier).save(subs.platformIds, includeFree: v)),
            ),
            _SwitchTile(
              key: const Key('settings_include_rentals'),
              title: 'Include paid rentals',
              subtitle: 'Apple TV / Amazon Store',
              value: prefs.includeRentals,
              onChanged: (v) => _guard(context, () => prefsController.edit((p) => p.copyWith(includeRentals: v))),
            ),
          ]),
          const SizedBox(height: 20),

          // 3. Notifications matrix (S3)
          const _SectionHeader('NOTIFICATIONS'),
          _Card(children: [
            for (final kind in NotificationKind.values)
              _SwitchTile(
                key: Key('settings_notify_${kind.key}'),
                title: kind.label,
                value: prefs.notificationOn(kind),
                onChanged: (v) => _guard(context, () => prefsController.setNotification(kind, v)),
              ),
            const Divider(color: TellyColors.borderGlass),
            _SwitchTile(
              key: const Key('settings_quiet_hours'),
              title: 'Quiet Hours (10 PM – 9 AM)',
              subtitle: 'Non-urgent alerts arrive as a morning bundle',
              value: prefs.quietHours,
              onChanged: (v) => _guard(context, () => prefsController.edit((p) => p.copyWith(quietHours: v))),
            ),
          ]),
          const SizedBox(height: 20),

          // 4. Haptics & motion (S4)
          const _SectionHeader('HAPTICS & MOTION'),
          _Card(children: [
            SegmentedButton<HapticsMode>(
              key: const Key('settings_haptics'),
              segments: [
                for (final m in HapticsMode.values) ButtonSegment(value: m, label: Text(m.label, style: const TextStyle(fontSize: 11))),
              ],
              selected: {prefs.haptics},
              onSelectionChanged: (s) => _guard(context, () => prefsController.edit((p) => p.copyWith(haptics: s.single))),
            ),
            const SizedBox(height: 8),
            _SwitchTile(
              key: const Key('settings_reduced_motion'),
              title: 'Reduced Motion',
              subtitle: 'Cross-fades instead of flips and springs',
              value: prefs.reducedMotion,
              onChanged: (v) => _guard(context, () => prefsController.edit((p) => p.copyWith(reducedMotion: v))),
            ),
          ]),
          const SizedBox(height: 20),

          // 5. Storage (S5)
          const _SectionHeader('STORAGE'),
          _Card(children: [
            _Tile(
              title: 'Cached posters & artwork',
              subtitle: switch (cacheSize) {
                AsyncData(:final value) => '${(value / (1024 * 1024)).toStringAsFixed(1)} MB',
                AsyncError() => 'Size unavailable',
                _ => 'Measuring…',
              },
              trailing: TextButton(
                key: const Key('settings_clear_cache'),
                onPressed: (cacheSize.valueOrNull ?? 0) > 0
                    ? () => _guard(context, () async {
                          await ref.read(imageCacheServiceProvider).clear();
                          ref.invalidate(imageCacheSizeProvider);
                        }, success: 'Artwork cache cleared')
                    : null,
                child: const Text('Clear Cache'),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // 6. Data portability
          const _SectionHeader('DATA & EXPORTS'),
          _Card(children: [
            _Tile(
              key: const Key('settings_export_csv'),
              title: 'Export My Canon (CSV)',
              subtitle: 'Both canons, shared as a spreadsheet',
              trailing: const Icon(Icons.ios_share, color: TellyColors.phosphorLime, size: 20),
              onTap: () => _guard(context, () => ref.read(canonExportServiceProvider).exportCsv()),
            ),
            const Divider(color: TellyColors.borderGlass),
            _Tile(
              key: const Key('settings_export_letterboxd'),
              title: 'Export Movies for Letterboxd',
              subtitle: 'Letterboxd import format (films only)',
              trailing: const Icon(Icons.ios_share, color: TellyColors.phosphorLime, size: 20),
              onTap: () => _guard(context, () => ref.read(canonExportServiceProvider).exportLetterboxd()),
            ),
          ]),
          const SizedBox(height: 20),

          // 7. Session & legal
          const _SectionHeader('LEGAL & SESSION'),
          _Card(children: [
            const _Tile(
              title: 'Terms & Privacy',
              subtitle: 'Opens in the browser (LEGAL-601)',
              trailing: Icon(Icons.open_in_new, color: TellyColors.textTertiary, size: 18),
            ),
            const Divider(color: TellyColors.borderGlass),
            _Tile(
              key: const Key('settings_sign_out'),
              title: me?.username == null ? 'Log Out' : 'Log Out @${me!.username}',
              trailing: const Icon(Icons.logout, color: TellyColors.textSecondary, size: 20),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            const Divider(color: TellyColors.borderGlass),
            const _Tile(
              title: 'Delete Account…',
              subtitle: '30-day soft deletion (LEGAL-601)',
              trailing: Icon(Icons.delete_forever, color: TellyColors.neonCoral, size: 20),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _VisibilityTile extends ConsumerWidget {
  final String current;
  const _VisibilityTile({required this.current});

  static const _labels = {'PUBLIC': 'Public', 'FRIENDS_ONLY': 'Friends only', 'GHOST': 'Ghost'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Tile(
      title: 'Privacy & Ghost Mode',
      subtitle: 'Who can see your canon',
      trailing: DropdownButton<String>(
        key: const Key('settings_visibility'),
        value: current,
        dropdownColor: TellyColors.backgroundCard,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold),
        items: [for (final e in _labels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) async {
          if (v == null || v == current) return;
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(profileRepositoryProvider).updateProfile(visibility: v);
            await ref.read(authControllerProvider.notifier).refreshProfile();
          } catch (_) {
            messenger.showSnackBar(const SnackBar(content: Text("Couldn't change your privacy setting.")));
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TellyTypography.labelSmall(color: TellyColors.textTertiary)
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Material(
        // A Material (not a coloured Container) so list tiles can paint their ink.
        color: TellyColors.backgroundSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TellyColors.borderGlass),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );
}

class _Tile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({super.key, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TellyTypography.bodyLarge(color: TellyColors.textPrimary)),
                    if (subtitle != null) Text(subtitle!, style: TellyTypography.caption()),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: TellyTypography.bodyLarge(color: TellyColors.textPrimary)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: TellyTypography.caption()),
        value: value,
        activeThumbColor: TellyColors.phosphorLime,
        onChanged: onChanged,
      );
}
