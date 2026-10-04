import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/avatar_picker.dart';
import '../../data/profile_repository.dart';

/// One pinned Top-3 title. Keyed by `(id, media_type)`: TMDB ids collide across canons.
typedef ShowcasePick = ({int titleId, String mediaType});

/// Unsaved Edit Profile form (adjacent_systems/02 §2). [pendingAvatar] is the cropped
/// photo shown in the preview; it is uploaded only on save.
class EditProfileDraft {
  final String username;
  final String displayName;
  final String bio;
  final String favoriteCreator;
  final String visibility; // PUBLIC | FRIENDS_ONLY | GHOST
  final String? avatarUrl;
  final Uint8List? pendingAvatar;
  final List<ShowcasePick> showcase;
  final bool saving;
  final String? error;

  const EditProfileDraft({
    required this.username,
    required this.displayName,
    this.bio = '',
    this.favoriteCreator = '',
    this.visibility = 'PUBLIC',
    this.avatarUrl,
    this.pendingAvatar,
    this.showcase = const [],
    this.saving = false,
    this.error,
  });

  static const maxShowcase = 3;
  static const maxBio = 160;

  /// Spec §2.1: 2–40 characters (emoji count as one).
  static String? validateDisplayName(String name) {
    final length = name.trim().runes.length;
    if (length < 2) return 'Display name needs at least 2 characters.';
    if (length > 40) return 'Display name can be at most 40 characters.';
    return null;
  }

  /// [error] is cleared unless provided.
  EditProfileDraft copyWith({
    String? displayName,
    String? bio,
    String? favoriteCreator,
    String? visibility,
    String? avatarUrl,
    Uint8List? pendingAvatar,
    bool clearPendingAvatar = false,
    List<ShowcasePick>? showcase,
    bool? saving,
    String? error,
  }) =>
      EditProfileDraft(
        username: username,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        favoriteCreator: favoriteCreator ?? this.favoriteCreator,
        visibility: visibility ?? this.visibility,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        pendingAvatar: clearPendingAvatar ? null : (pendingAvatar ?? this.pendingAvatar),
        showcase: showcase ?? this.showcase,
        saving: saving ?? this.saving,
        error: error,
      );
}

/// Loads my profile into an [EditProfileDraft] and saves it: avatar → `avatars` bucket,
/// name/bio/visibility/Top-3 → `users`, favourite creator → `users.preferences` (FE-608).
class EditProfileController extends AutoDisposeAsyncNotifier<EditProfileDraft> {
  @override
  Future<EditProfileDraft> build() async {
    // Rebuild only when the signed-in user changes, not when save() refreshes the profile.
    final (userId, initializing) = ref.watch(
      authControllerProvider.select((s) => (s.user?.id, s.status == AuthStepStatus.initializing)),
    );
    if (initializing) return Completer<EditProfileDraft>().future; // session not restored yet
    final me = ref.read(authControllerProvider).user;
    if (userId == null || me == null) throw StateError('Not signed in');

    final repository = ref.watch(profileRepositoryProvider);
    final card = me.hasHandle ? await repository.fetchByHandle(me.username!) : null;
    final preferences = await repository.fetchPreferences();
    return EditProfileDraft(
      username: me.username ?? '',
      displayName: card?.displayName ?? me.displayName,
      bio: card?.bio ?? me.bio ?? '',
      favoriteCreator: (preferences['favorite_creator'] as String?) ?? '',
      visibility: me.visibilityMode,
      avatarUrl: card?.avatarUrl ?? me.avatarUrl,
      showcase: card?.pinnedShowcase ?? const [],
    );
  }

  void _edit(EditProfileDraft Function(EditProfileDraft) change) {
    final draft = state.valueOrNull;
    if (draft != null) state = AsyncData(change(draft));
  }

  void setDisplayName(String v) => _edit((d) => d.copyWith(displayName: v));
  void setBio(String v) => _edit((d) => d.copyWith(bio: v));
  void setFavoriteCreator(String v) => _edit((d) => d.copyWith(favoriteCreator: v));
  void setVisibility(String v) => _edit((d) => d.copyWith(visibility: v));

  /// Photo library → 1:1 crop; the crop shows in the preview until saved.
  Future<void> pickAvatar() async {
    try {
      final bytes = await ref.read(avatarPickerProvider).pickSquareAvatar();
      if (bytes != null) _edit((d) => d.copyWith(pendingAvatar: bytes));
    } catch (_) {
      _edit((d) => d.copyWith(error: "Couldn't open your photo library."));
    }
  }

  /// Pins [pick] into [slot] (0–2). If it was pinned in another slot the two swap;
  /// an empty slot past the end appends.
  void setShowcaseSlot(int slot, ShowcasePick pick) => _edit((d) {
        if (slot < 0 || slot >= EditProfileDraft.maxShowcase) return d;
        final list = [...d.showcase];
        final existing = list.indexOf(pick);
        if (slot < list.length) {
          final previous = list[slot];
          list[slot] = pick;
          if (existing >= 0 && existing != slot) list[existing] = previous;
        } else if (existing < 0) {
          list.add(pick);
        }
        return d.copyWith(showcase: List.unmodifiable(list));
      });

  void clearShowcaseSlot(int slot) => _edit((d) {
        if (slot < 0 || slot >= d.showcase.length) return d;
        return d.copyWith(showcase: List.unmodifiable([...d.showcase]..removeAt(slot)));
      });

  /// Persists the draft. False (with [EditProfileDraft.error] set) on validation or server failure.
  Future<bool> save() async {
    final draft = state.valueOrNull;
    if (draft == null || draft.saving) return false;
    final invalid = EditProfileDraft.validateDisplayName(draft.displayName);
    if (invalid != null) {
      _edit((d) => d.copyWith(error: invalid));
      return false;
    }

    _edit((d) => d.copyWith(saving: true));
    final repository = ref.read(profileRepositoryProvider);
    try {
      String? uploadedUrl;
      if (draft.pendingAvatar != null) {
        uploadedUrl = await repository.uploadAvatar(draft.pendingAvatar!);
        // A retry after a later failure must not upload again.
        _edit((d) => d.copyWith(avatarUrl: uploadedUrl, clearPendingAvatar: true, saving: true));
      }
      await repository.updateProfile(
        displayName: draft.displayName.trim(),
        bio: draft.bio.trim(),
        avatarUrl: uploadedUrl,
        visibility: draft.visibility,
        pinnedShowcase: draft.showcase,
      );
      await repository.updatePreferences({'favorite_creator': draft.favoriteCreator.trim()});
    } catch (_) {
      _edit((d) => d.copyWith(saving: false, error: "Couldn't save your profile. Check your connection and try again."));
      return false;
    }
    _edit((d) => d.copyWith(saving: false));
    ref.invalidate(myPinnedShowcaseProvider);
    await ref.read(authControllerProvider.notifier).refreshProfile();
    return true;
  }
}

final editProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, EditProfileDraft>(EditProfileController.new);

/// My saved Top-3 (`users.pinned_showcase`) for SCR-14; empty when unknown or offline.
final myPinnedShowcaseProvider = FutureProvider.autoDispose<List<ShowcasePick>>((ref) async {
  final handle = ref.watch(authControllerProvider.select((s) => s.user?.username));
  if (handle == null || handle.isEmpty) return const [];
  try {
    return (await ref.watch(profileRepositoryProvider).fetchByHandle(handle))?.pinnedShowcase ?? const [];
  } catch (_) {
    return const [];
  }
});
