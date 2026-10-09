library edit_profile_studio;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_neon_badge.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../controllers/edit_profile_controller.dart';
import '../controllers/profile_controller.dart';

/// Edit Profile Studio: avatar cropper, name/bio, Top 3 showcase and visibility (FE-507).
/// Conforms to `docs/adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md` §2 and §4.
///
/// FE-608: all form state lives in [editProfileControllerProvider]; the photo is picked
/// and cropped 1:1, previewed, and uploaded to the `avatars` bucket on save; the Top 3
/// is chosen from my own canon and saved to `users.pinned_showcase`.
class EditProfileStudioScreen extends ConsumerWidget {
  const EditProfileStudioScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref.read(editProfileControllerProvider.notifier).save();
    if (!saved || !context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: const Text('Profile saved'), backgroundColor: TellyColors.cardOf(context)));
    if (context.mounted) {
      final rootNav = Navigator.of(context, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        try {
          context.pop();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(editProfileControllerProvider);
    final draft = async.valueOrNull;
    final canSave = draft != null && !draft.saving;

    return Scaffold(
      appBar: TellySubpageAppBar(
        nav: TellyNavKind.close,
        title: 'Edit profile',
        onNav: () {
          final rootNav = Navigator.of(context, rootNavigator: true);
          if (rootNav.canPop()) {
            rootNav.pop();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            try {
              context.pop();
            } catch (_) {}
          }
        },
        actions: [
          TextButton(
            key: const Key('edit_profile_save'),
            onPressed: canSave ? () => _save(context, ref) : null,
            child: draft?.saving == true
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    'Save',
                    style: TellyTypography.labelLarge(color: canSave ? TellyColors.primaryAccentOf(context) : TellyColors.textTertiaryOf(context))
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) => _EditProfileForm(initial: value, onSave: () => _save(context, ref)),
        AsyncError() => Center(
            key: const Key('edit_profile_load_error'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Couldn't load your profile.", style: TellyTypography.bodyMedium()),
                TextButton(onPressed: () => ref.invalidate(editProfileControllerProvider), child: const Text('Retry')),
              ],
            ),
          ),
        _ => const Center(key: Key('edit_profile_loading'), child: CircularProgressIndicator()),
      },
    );
  }
}

/// The form. Text controllers are purely visual and seeded once from [initial]; every
/// edit is forwarded to the controller, which owns the draft.
class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.initial, required this.onSave});
  final EditProfileDraft initial;
  final VoidCallback onSave;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _displayName = TextEditingController(text: widget.initial.displayName);
  late final _bio = TextEditingController(text: widget.initial.bio);
  late final _creator = TextEditingController(text: widget.initial.favoriteCreator);

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _creator.dispose();
    super.dispose();
  }

  EditProfileController get _controller => ref.read(editProfileControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(editProfileControllerProvider).valueOrNull ?? widget.initial;
    final canon = ref.watch(profileCanonProvider);
    final myTitles = [...canon.movies, ...canon.series];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (draft.error != null)
          Container(
            key: const Key('edit_profile_error'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TellyColors.neonCoralOf(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.neonCoralOf(context).withValues(alpha: 0.5)),
            ),
            child: Text(draft.error!, style: TellyTypography.bodyMedium(color: TellyColors.neonCoralOf(context))),
          ),

        // 1. Avatar (spec §2.1: photo library + 1:1 circular crop)
        Center(child: _AvatarEditor(draft: draft, onPick: _controller.pickAvatar)),
        const SizedBox(height: 20),

        // 2. Display name
        const _FieldHeader('DISPLAY NAME'),
        _TellyTextField(
          key: const Key('edit_profile_display_name'),
          controller: _displayName,
          hint: 'Your display name',
          onChanged: _controller.setDisplayName,
        ),
        const SizedBox(height: 8),

        // 3. Handle (read-only here; reserved through the handle flow)
        const _FieldHeader('HANDLE'),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            draft.username.isEmpty ? 'No handle reserved yet' : '@${draft.username}',
            key: const Key('edit_profile_handle'),
            style: TellyTypography.bodyMedium(color: TellyColors.primaryAccentOf(context)).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Bio / manifesto
        const _FieldHeader('BIO / TV MANIFESTO (MAX 160 CHARS)'),
        _TellyTextField(
          key: const Key('edit_profile_bio'),
          controller: _bio,
          hint: 'Your cinematic bio...',
          maxLines: 3,
          maxLength: EditProfileDraft.maxBio,
          onChanged: _controller.setBio,
        ),
        const SizedBox(height: 8),

        // 5. Favourite creator
        const _FieldHeader('FAVORITE SHOWRUNNER / CREATOR'),
        _TellyTextField(
          key: const Key('edit_profile_creator'),
          controller: _creator,
          hint: 'e.g. Jesse Armstrong, Vince Gilligan',
          onChanged: _controller.setFavoriteCreator,
        ),
        const SizedBox(height: 24),

        // 6. Top 3 showcase, chosen from my canon
        const _SectionTitle('TOP 3 PROFILE SHOWCASE'),
        Text(
          'Pinned to the top of your profile. Pick from titles you have ranked.',
          style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
              .copyWith(fontSize: 13.0, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var slot = 0; slot < EditProfileDraft.maxShowcase; slot++)
          _ShowcaseSlot(
            slot: slot,
            entry: slot < draft.showcase.length ? _resolve(draft.showcase[slot], myTitles) : null,
            pick: slot < draft.showcase.length ? draft.showcase[slot] : null,
            onEdit: () => _chooseShowcase(slot, myTitles),
            onClear: () => _controller.clearShowcaseSlot(slot),
          ),
        const SizedBox(height: 24),

        // 7. Account visibility (spec §4)
        const _SectionTitle('ACCOUNT VISIBILITY'),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TellyColors.cardOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TellyColors.borderGlassOf(context)),
          ),
          child: Column(
            children: [
              for (final (i, mode) in _visibilityModes.indexed) ...[
                if (i > 0) Divider(color: TellyColors.borderGlassOf(context)),
                _VisibilityTile(
                  title: mode.$2,
                  subtitle: mode.$3,
                  selected: draft.visibility == mode.$1,
                  onTap: () => _controller.setVisibility(mode.$1),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),

        TellyPrimaryButton(label: 'Save Profile Changes', onPressed: draft.saving ? null : widget.onSave),
        const SizedBox(height: 32),
      ],
    );
  }

  static const _visibilityModes = [
    ('PUBLIC', 'Public', 'Anyone can see your rankings, follow, & compare taste.'),
    ('FRIENDS_ONLY', 'Friends Only (Private)', 'Requires follow approval to view your ratings & taste match.'),
    ('GHOST', 'Ghost Mode', 'Hidden from global search. Direct link only.'),
  ];

  static CanonEntry? _resolve(ShowcasePick pick, List<CanonEntry> titles) {
    for (final t in titles) {
      if (t.id == pick.titleId && t.mediaType == pick.mediaType) return t;
    }
    return null;
  }

  Future<void> _chooseShowcase(int slot, List<CanonEntry> titles) async {
    final chosen = await showModalBottomSheet<CanonEntry>(
      context: context,
      backgroundColor: TellyColors.cardOf(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('PIN TO SLOT #${slot + 1}', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(ctx))),
              ),
              if (titles.isEmpty)
                Padding(
                  key: const Key('showcase_picker_empty'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Text(
                    'Rank a few titles first — your showcase comes from your rankings.',
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(ctx)),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in titles)
                        ListTile(
                          key: Key('showcase_pick_${t.mediaType}_${t.id}'),
                          leading: Text(t.mediaType == 'movie' ? '🎬' : '📺', style: const TextStyle(fontSize: 20)),
                          title: Text(t.title, style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(ctx))),
                          subtitle: Text(
                            '#${t.rankPosition} · ${t.calculatedScore.toStringAsFixed(2)}',
                            style: TellyTypography.caption(color: TellyColors.textTertiaryOf(ctx)),
                          ),
                          onTap: () => Navigator.of(ctx).pop(t),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) _controller.setShowcaseSlot(slot, (titleId: chosen.id, mediaType: chosen.mediaType));
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({required this.draft, required this.onPick});
  final EditProfileDraft draft;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = draft.pendingAvatar != null
        ? MemoryImage(draft.pendingAvatar!)
        : (draft.avatarUrl?.isNotEmpty ?? false)
            ? NetworkImage(draft.avatarUrl!)
            : null;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              key: const Key('edit_profile_avatar'),
              radius: 46,
              backgroundColor: TellyColors.cardOf(context),
              backgroundImage: image,
              // An unreachable avatar URL just shows the bare circle.
              onBackgroundImageError: image == null ? null : (_, __) {},
              child: image == null ? Icon(Icons.person, size: 44, color: TellyColors.textTertiaryOf(context)) : null,
            ),
            Material(
              color: TellyColors.primaryAccentOf(context),
              shape: CircleBorder(side: BorderSide(color: TellyColors.canvasOf(context), width: 2)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.camera_alt,
                      color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
                      size: 16,
                      semanticLabel: 'Change photo'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('edit_profile_change_photo'),
          onPressed: onPick,
          child: Text('Change Photo',
              style: TellyTypography.caption(color: TellyColors.primaryAccentOf(context))
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 12.0)),
        ),
        if (draft.pendingAvatar != null)
          Text('New photo will upload when you save.', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
      ],
    );
  }
}

class _ShowcaseSlot extends StatelessWidget {
  const _ShowcaseSlot({
    required this.slot,
    required this.entry,
    required this.pick,
    required this.onEdit,
    required this.onClear,
  });
  final int slot;
  final CanonEntry? entry;
  final ShowcasePick? pick;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // A pinned title that is no longer in my canon still shows (and can be cleared).
    final label = entry?.title ?? (pick == null ? 'Empty Slot' : 'Title #${pick!.titleId}');
    return Container(
      key: Key('showcase_slot_$slot'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: TellyColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        children: [
          TellyNeonBadge(label: '#${slot + 1}', variant: TellyBadgeVariant.neutral),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TellyTypography.bodyMedium(color: pick == null ? TellyColors.textTertiaryOf(context) : TellyColors.textPrimaryOf(context)),
            ),
          ),
          if (pick != null)
            IconButton(
              key: Key('showcase_clear_$slot'),
              tooltip: 'Remove',
              icon: Icon(Icons.close, color: TellyColors.textTertiaryOf(context), size: 18),
              onPressed: onClear,
            ),
          IconButton(
            key: Key('showcase_edit_$slot'),
            tooltip: 'Choose title',
            icon: Icon(Icons.edit, color: TellyColors.textTertiaryOf(context), size: 18),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? TellyColors.primaryAccentOf(context) : TellyColors.textTertiaryOf(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TellyTypography.bodyMedium(color: selected ? TellyColors.primaryAccentOf(context) : TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          title,
          style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context))
              .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w800, fontSize: 11.5),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
              .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
        ),
      );
}

class _TellyTextField extends StatelessWidget {
  const _TellyTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength == null
          ? null
          : (context, {required currentLength, required isFocused, maxLength}) => Text(
                '$currentLength/$maxLength',
                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 12.0),
              ),
      style: TextStyle(color: TellyColors.textPrimaryOf(context), fontSize: 16.0, fontWeight: FontWeight.w600),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: TellyColors.cardOf(context),
        hintText: hint,
        hintStyle: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border(TellyColors.strokeOf(context)),
        enabledBorder: border(TellyColors.strokeOf(context)),
        focusedBorder: border(TellyColors.primaryAccentOf(context)),
      ),
    );
  }
}
