import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/profile/data/avatar_picker.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/edit_profile_controller.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_avatar_picker.dart';
import '../../fakes/fake_profile_repository.dart';

UserProfile kai() => UserProfile(
      id: 'u1',
      username: 'kai',
      displayName: 'Kai',
      bio: 'auth bio',
      visibilityMode: 'FRIENDS_ONLY',
      onboardingCompleted: true,
      createdAt: DateTime(2026),
    );

PublicProfile kaiCard({List<ShowcasePick> showcase = const []}) => PublicProfile(
      id: 'u1',
      username: 'kai',
      displayName: 'Kai Okafor',
      bio: 'Prestige TV only.',
      visibility: 'FRIENDS_ONLY',
      pinnedShowcase: showcase,
    );

void main() {
  late FakeProfileRepository profiles;
  late FakeAvatarPicker picker;
  late ProviderContainer container;

  setUp(() {
    profiles = FakeProfileRepository()
      ..profiles['kai'] = kaiCard(showcase: [(titleId: 7, mediaType: 'tv')])
      ..preferences = {'favorite_creator': 'Vince Gilligan', 'haptics': 'full'};
    picker = FakeAvatarPicker(Uint8List.fromList([1, 2, 3]));
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1', profile: kai())),
      profileRepositoryProvider.overrideWithValue(profiles),
      avatarPickerProvider.overrideWithValue(picker),
    ]);
    addTearDown(container.dispose);
  });

  Future<EditProfileDraft> loaded() async {
    container.listen(editProfileControllerProvider, (_, __) {});
    for (var i = 0; i < 100 && !container.read(editProfileControllerProvider).hasValue; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(editProfileControllerProvider).requireValue;
  }

  EditProfileController controller() => container.read(editProfileControllerProvider.notifier);
  EditProfileDraft draft() => container.read(editProfileControllerProvider).requireValue;

  group('FE-608: EditProfileController', () {
    test('loads the draft from my profile card and preferences, never from mock defaults', () async {
      final d = await loaded();
      expect(d.username, 'kai');
      expect(d.displayName, 'Kai Okafor');
      expect(d.bio, 'Prestige TV only.');
      expect(d.visibility, 'FRIENDS_ONLY');
      expect(d.favoriteCreator, 'Vince Gilligan');
      expect(d.showcase, [(titleId: 7, mediaType: 'tv')]);
      expect(d.pendingAvatar, isNull);
    });

    test('a cropped photo becomes the pending avatar; cancelling leaves it unchanged', () async {
      await loaded();
      await controller().pickAvatar();
      expect(draft().pendingAvatar, [1, 2, 3]);

      picker.result = null; // user backed out of the cropper
      await controller().pickAvatar();
      expect(draft().pendingAvatar, [1, 2, 3]);
      expect(profiles.uploads, isEmpty, reason: 'nothing uploads before save');
    });

    test('a picker failure is reported instead of crashing', () async {
      await loaded();
      picker.fail = true;
      await controller().pickAvatar();
      expect(draft().error, contains('photo library'));
      expect(draft().pendingAvatar, isNull);
    });

    test('save uploads the crop, then writes profile, Top 3 and favourite creator', () async {
      await loaded();
      await controller().pickAvatar();
      controller()
        ..setDisplayName('  Kai O.  ')
        ..setBio('New manifesto')
        ..setVisibility('GHOST')
        ..setFavoriteCreator('Mike White')
        ..setShowcaseSlot(1, (titleId: 7, mediaType: 'movie'));

      expect(await controller().save(), isTrue);

      expect(profiles.uploads.single, [1, 2, 3]);
      expect(profiles.updates.single, {
        'display_name': 'Kai O.',
        'bio': 'New manifesto',
        'avatar_url': 'https://cdn.test/avatars/me.jpg',
        'visibility_mode': 'GHOST',
        // Same TMDB id in both canons stays two distinct picks.
        'pinned_showcase': [(titleId: 7, mediaType: 'tv'), (titleId: 7, mediaType: 'movie')],
      });
      expect(profiles.preferences['favorite_creator'], 'Mike White');
      expect(profiles.preferences['haptics'], 'full', reason: 'other preferences are preserved');
      expect(draft().pendingAvatar, isNull);
      expect(draft().avatarUrl, 'https://cdn.test/avatars/me.jpg');
    });

    test('without a new photo, save does not upload or overwrite avatar_url', () async {
      await loaded();
      expect(await controller().save(), isTrue);
      expect(profiles.uploads, isEmpty);
      expect(profiles.updates.single.containsKey('avatar_url'), isFalse);
    });

    test('an invalid display name blocks the save (spec §2.1: 2–40 characters)', () async {
      await loaded();
      controller().setDisplayName(' K ');
      expect(await controller().save(), isFalse);
      expect(draft().error, contains('at least 2'));
      expect(profiles.updates, isEmpty);

      controller().setDisplayName('x' * 41);
      expect(await controller().save(), isFalse);
      expect(draft().error, contains('at most 40'));
    });

    test('a server failure keeps the draft, clears saving and explains', () async {
      await loaded();
      controller().setBio('unsaved');
      profiles.failWrites = true;
      expect(await controller().save(), isFalse);
      expect(draft().saving, isFalse);
      expect(draft().error, contains("Couldn't save"));
      expect(draft().bio, 'unsaved');
    });

    test('showcase slots: fill in order, swap on re-pin, never exceed three, clear', () async {
      await loaded();
      const a = (titleId: 1, mediaType: 'movie');
      const b = (titleId: 2, mediaType: 'tv');
      const c = (titleId: 3, mediaType: 'tv');
      const existing = (titleId: 7, mediaType: 'tv');

      controller()
        ..setShowcaseSlot(1, a)
        ..setShowcaseSlot(2, b);
      expect(draft().showcase, [existing, a, b]);

      controller().setShowcaseSlot(0, b); // b was in slot 2 → swaps with slot 0
      expect(draft().showcase, [b, a, existing]);

      controller().setShowcaseSlot(3, c); // out of range
      expect(draft().showcase, hasLength(3));

      controller().setShowcaseSlot(1, c); // replaces a
      expect(draft().showcase, [b, c, existing]);

      controller().clearShowcaseSlot(0);
      expect(draft().showcase, [c, existing]);
    });
  });

  group('FE-608: myPinnedShowcaseProvider', () {
    test('returns my saved Top 3, or empty when the server is unreachable', () async {
      container.listen(myPinnedShowcaseProvider, (_, __) {});
      await loaded(); // auth restored
      expect(await container.read(myPinnedShowcaseProvider.future), [(titleId: 7, mediaType: 'tv')]);

      profiles.failReads = true;
      container.invalidate(myPinnedShowcaseProvider);
      expect(await container.read(myPinnedShowcaseProvider.future), isEmpty);
    });
  });
}
