import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/profile/data/avatar_picker.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/edit_profile_studio_screen.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_avatar_picker.dart';
import '../../fakes/fake_profile_repository.dart';

class _FixedCanon extends ProfileCanonNotifier {
  @override
  ProfileCanonState build() => const ProfileCanonState(
        movies: [
          CanonEntry(id: 7, title: 'Heat', mediaType: 'movie', rankPosition: 1, calculatedScore: 10.0),
        ],
        series: [
          CanonEntry(id: 7, title: 'The Wire', mediaType: 'tv', rankPosition: 1, calculatedScore: 10.0),
          CanonEntry(id: 8, title: 'Severance', mediaType: 'tv', rankPosition: 2, calculatedScore: 9.1),
        ],
      );
}

void main() {
  late FakeProfileRepository profiles;
  late FakeAvatarPicker picker;

  setUp(() {
    profiles = FakeProfileRepository()
      ..profiles['kai'] = const PublicProfile(
        id: 'u1',
        username: 'kai',
        displayName: 'Kai Okafor',
        bio: 'Prestige TV only.',
        pinnedShowcase: [(titleId: 7, mediaType: 'tv')],
      );
    picker = FakeAvatarPicker(kOnePixelPng);
  });

  /// Opens the studio from a host page so a successful save can pop back to it.
  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          signedInUserId: 'u1',
          profile: UserProfile(id: 'u1', username: 'kai', displayName: 'Kai', createdAt: DateTime(2026)),
        )),
        profileRepositoryProvider.overrideWithValue(profiles),
        avatarPickerProvider.overrideWithValue(picker),
        profileCanonProvider.overrideWith(_FixedCanon.new),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const EditProfileStudioScreen())),
              child: const Text('host page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('host page'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(); // push the route
      await tester.pump(const Duration(milliseconds: 500)); // finish the transition; the spinner never settles
    }
  }

  group('FE-507 / FE-608: Edit Profile Studio', () {
    testWidgets('shows a loading state, then my real profile (no mock defaults)', (tester) async {
      profiles.gate = Completer<void>();
      await open(tester, settle: false);
      expect(find.byKey(const Key('edit_profile_loading')), findsOneWidget);

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Kai Okafor'), findsOneWidget);
      expect(find.text('@kai'), findsOneWidget);
      expect(find.text('Prestige TV only.'), findsOneWidget);
      expect(find.text('The Wire'), findsOneWidget, reason: 'pinned (7, tv) resolves to the series, not the movie');
      expect(find.text('Heat'), findsNothing);
      expect(find.text('Jordan Miller'), findsNothing);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      profiles.failReads = true;
      await open(tester);
      expect(find.byKey(const Key('edit_profile_load_error')), findsOneWidget);

      profiles.failReads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Kai Okafor'), findsOneWidget);
    });

    testWidgets('the avatar crop result updates the preview before upload', (tester) async {
      await open(tester);
      CircleAvatar avatar() => tester.widget<CircleAvatar>(find.byKey(const Key('edit_profile_avatar')));
      expect(avatar().backgroundImage, isNull);

      await tester.tap(find.byKey(const Key('edit_profile_change_photo')));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      final image = avatar().backgroundImage;
      expect(image, isA<MemoryImage>());
      expect((image! as MemoryImage).bytes, kOnePixelPng);
      expect(find.text('New photo will upload when you save.'), findsOneWidget);
      expect(profiles.uploads, isEmpty);
    });

    testWidgets('save uploads the photo, persists edits and the Top 3, then closes', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('edit_profile_change_photo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit_profile_bio')), 'Severance truther.');
      await tester.tap(find.text('Ghost Mode'));

      // Slot #2 ← Severance from my canon.
      await tester.tap(find.byKey(const Key('showcase_edit_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('showcase_pick_tv_8')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('showcase_slot_1')), matching: find.text('Severance')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('edit_profile_save')));
      await tester.pumpAndSettle();

      expect(profiles.uploads.single, kOnePixelPng);
      final update = profiles.updates.single;
      expect(update['bio'], 'Severance truther.');
      expect(update['visibility_mode'], 'GHOST');
      expect(update['avatar_url'], 'https://cdn.test/avatars/me.jpg');
      expect(update['pinned_showcase'], [(titleId: 7, mediaType: 'tv'), (titleId: 8, mediaType: 'tv')]);
      expect(find.text('host page'), findsOneWidget, reason: 'the studio closes after saving');
      expect(find.text('Profile saved'), findsOneWidget);
    });

    testWidgets('a failed save keeps the studio open with an error', (tester) async {
      await open(tester);
      profiles.failWrites = true;
      await tester.tap(find.byKey(const Key('edit_profile_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_error')), findsOneWidget);
      expect(find.textContaining("Couldn't save your profile"), findsOneWidget);
      expect(find.text('EDIT PROFILE'), findsOneWidget);
    });

    testWidgets('clearing a showcase slot removes the pin', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('showcase_clear_0')));
      await tester.pumpAndSettle();
      expect(find.text('The Wire'), findsNothing);

      await tester.tap(find.byKey(const Key('edit_profile_save')));
      await tester.pumpAndSettle();
      expect(profiles.updates.single['pinned_showcase'], isEmpty);
    });
  });
}
