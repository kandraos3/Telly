import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';

void main() {
  group('DEV-601: StoryShareService Tests', () {
    test('SharePlusStoryShareService formats starter canon story text properly', () async {
      String? capturedText;
      String? capturedSubject;

      final service = SharePlusStoryShareService(
        shareText: (text, {subject}) async {
          capturedText = text;
          capturedSubject = subject;
        },
      );

      await service.shareStarterCanon(
        canonLabel: 'Prestige TV Canon',
        topTitles: ['The Wire', 'Succession', 'Severance'],
      );

      expect(capturedSubject, equals('My Prestige TV Canon Top Shows'));
      expect(capturedText, contains('🎬 My Prestige TV Canon on Telly:'));
      expect(capturedText, contains('#1 The Wire'));
      expect(capturedText, contains('#2 Succession'));
      expect(capturedText, contains('#3 Severance'));
      expect(capturedText, contains('https://telly.app'));
    });

    test('FakeStoryShareService records shared stories without platform channels', () async {
      final fake = FakeStoryShareService();

      expect(fake.sharedStories, isEmpty);

      await fake.shareStarterCanon(
        canonLabel: 'Movie Canon',
        topTitles: ['Parasite', 'Interstellar'],
      );

      expect(fake.sharedStories.length, equals(1));
      expect(fake.sharedStories.first.canonLabel, equals('Movie Canon'));
      expect(fake.sharedStories.first.topTitles, equals(['Parasite', 'Interstellar']));
    });
  });
}

