library settings_hub_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/biometrics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../legal/domain/legal_markdown.dart';
import '../../../legal/presentation/screens/legal_document_screen.dart';
import '../../../onboarding/presentation/screens/streaming_setup_screen.dart';
import '../../../onboarding/data/canon_import_service.dart';
import '../../../onboarding/presentation/widgets/import_sources.dart';
import '../../data/profile_repository.dart';
import '../../data/settings_services.dart';
import '../controllers/settings_controllers.dart';
import '../controllers/watch_history_import_controller.dart';

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
          tooltip: 'Back',
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
              subtitle: 'Face ID / Fingerprint unlock',
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
            _SwitchTile(
              key: const Key('settings_notify_all'),
              title: 'All Notifications',
              subtitle: 'Master switch to enable or pause all notifications',
              value: NotificationKind.values.every(prefs.notificationOn),
              onChanged: (v) => _guard(context, () => prefsController.setAllNotifications(v)),
            ),
            const Divider(color: TellyColors.borderGlass),
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

          // Appearance & Theme (FE-THEME-01)
          const _SectionHeader('APPEARANCE & THEME'),
          _Card(children: [
            const _Tile(
              title: 'Color Theme',
              subtitle: 'Midnight Cathode (Dark) or Day Cathode (Light)',
            ),
            const SizedBox(height: 6),
            SegmentedButton<TellyThemeMode>(
              key: const Key('settings_theme_mode'),
              segments: [
                for (final m in TellyThemeMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(m.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    icon: Icon(
                      m == TellyThemeMode.system
                          ? Icons.brightness_auto
                          : m == TellyThemeMode.dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                      size: 16,
                    ),
                  ),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (s) =>
                  _guard(context, () => prefsController.edit((p) => p.copyWith(themeMode: s.single))),
            ),
            const SizedBox(height: 4),
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

          // 6. Data portability: imports (FE-SETTINGS-02), then exports
          const _SectionHeader('IMPORT WATCH HISTORY'),
          const _ImportWatchHistoryCard(),
          const SizedBox(height: 20),
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
            _Tile(
              key: const Key('settings_terms'),
              title: 'Terms of Service',
              subtitle: 'Read in app',
              trailing: const Icon(Icons.chevron_right, color: TellyColors.textTertiary, size: 20),
              onTap: () => LegalDocumentScreen.open(context, LegalDocument.terms),
            ),
            const Divider(color: TellyColors.borderGlass),
            _Tile(
              key: const Key('settings_privacy'),
              title: 'Privacy Policy',
              subtitle: 'Read in app',
              trailing: const Icon(Icons.chevron_right, color: TellyColors.textTertiary, size: 20),
              onTap: () => LegalDocumentScreen.open(context, LegalDocument.privacy),
            ),
            const Divider(color: TellyColors.borderGlass),
            _Tile(
              key: const Key('settings_sign_out'),
              title: me?.username == null ? 'Log Out' : 'Log Out @${me!.username}',
              trailing: const Icon(Icons.logout, color: TellyColors.textSecondary, size: 20),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            const Divider(color: TellyColors.borderGlass),
            _Tile(
              key: const Key('settings_delete_account'),
              title: 'Delete Account…',
              subtitle: '30-day soft deletion grace period',
              trailing: const Icon(Icons.delete_forever, color: TellyColors.neonCoral, size: 20),
              onTap: () => _confirmAccountDeletion(context, ref),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmAccountDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TellyColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete Account?',
                style: TellyTypography.titleLarge(color: TellyColors.neonCoral)
                    .copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'Your profile, rankings, duel history, and social connections will become invisible immediately. '
                'You will have a 30-day grace period to log back in and cancel deletion before permanent destruction.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('delete_account_cancel_button'),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: TellyColors.borderGlass),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: TellyColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('delete_account_confirm_button'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TellyColors.neonCoral,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final database = ref.read(databaseProvider);
      await ref.read(authControllerProvider.notifier).deleteAccount(database: database);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion requested. 30-day grace period started.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't process deletion. Check your connection.")),
        );
      }
    }
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

/// Letterboxd CSV / AniList import into my canons, with progress and a summary.
class _ImportWatchHistoryCard extends ConsumerWidget {
  const _ImportWatchHistoryCard();

  Future<void> _letterboxd(WidgetRef ref) async {
    final csv = await ref.read(csvFilePickerProvider)();
    if (csv == null) return;
    await ref.read(watchHistoryImportProvider.notifier).importLetterboxd(csv);
  }

  Future<void> _aniList(BuildContext context, WidgetRef ref) async {
    final username = await showDialog<String>(context: context, builder: (_) => const AniListUsernameDialog());
    if (username == null || username.isEmpty) return;
    await ref.read(watchHistoryImportProvider.notifier).importAniList(username);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchHistoryImportProvider);
    final running = state is ImportRunning;
    return _Card(children: [
      _Tile(
        key: const Key('settings_import_letterboxd'),
        title: 'Import from Letterboxd',
        subtitle: 'Pick watched.csv or ratings.csv from your export',
        trailing: const Icon(Icons.upload_file_rounded, color: TellyColors.phosphorLime, size: 20),
        onTap: running ? null : () => _letterboxd(ref),
      ),
      const Divider(color: TellyColors.borderGlass),
      _Tile(
        key: const Key('settings_import_anilist'),
        title: 'Import from AniList',
        subtitle: 'Your completed anime, by AniList username',
        trailing: const Icon(Icons.person_search_rounded, color: TellyColors.phosphorLime, size: 20),
        onTap: running ? null : () => _aniList(context, ref),
      ),
      ...switch (state) {
        ImportIdle() => const <Widget>[],
        ImportRunning(:final source) => [
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: TellyColors.phosphorLime, backgroundColor: TellyColors.backgroundCard),
            const SizedBox(height: 8),
            Text(
              'Importing from ${source.label}… matching each title takes a moment.',
              key: const Key('settings_import_running'),
              style: TellyTypography.caption(color: TellyColors.textSecondary),
            ),
          ],
        ImportDone(:final source, :final result) => [
            const SizedBox(height: 10),
            _ImportSummary(source: source, result: result, onDismiss: ref.read(watchHistoryImportProvider.notifier).dismiss),
          ],
        ImportFailed(:final message) => [
            const SizedBox(height: 10),
            Text(message, key: const Key('settings_import_error'), style: TellyTypography.caption(color: TellyColors.neonCoral)),
          ],
      },
    ]);
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.source, required this.result, required this.onDismiss});

  final ImportSource source;
  final ImportResult result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final lines = [
      'Added ${result.added} ${result.added == 1 ? 'title' : 'titles'} from ${source.label}',
      if (result.alreadyRanked > 0) '${result.alreadyRanked} already in your canon',
      if (result.unmatched.isNotEmpty) "${result.unmatched.length} couldn't be matched",
    ];
    return Container(
      key: const Key('settings_import_summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.phosphorLime.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.phosphorLime.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: TellyColors.phosphorLime, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lines.join(' · '), style: TellyTypography.bodyMedium(color: TellyColors.textPrimary)),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18, color: TellyColors.textTertiary),
              ),
            ],
          ),
          if (result.added > 0)
            Text(
              'New titles sit at the bottom of your canon. Duel them to place them properly.',
              style: TellyTypography.caption(color: TellyColors.textSecondary),
            ),
          if (result.unmatched.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              // Its own Material: the summary box's tint would otherwise hide the ink.
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  key: const Key('settings_import_unmatched'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('See unmatched titles', style: TellyTypography.labelMedium(color: TellyColors.textSecondary)),
                  children: [
                    for (final t in result.unmatched.take(50))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('• $t', style: TellyTypography.caption(color: TellyColors.textTertiary)),
                      ),
                    if (result.unmatched.length > 50)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('…and ${result.unmatched.length - 50} more', style: TellyTypography.caption()),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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
