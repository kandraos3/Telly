import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/site/src/content.dart';
import '../../tool/site/src/scenes.dart';
import '../../tool/site/src/tokens.dart';

const _minimal = '''
site:
  name: Telly
  url: https://example.com/Telly/
  title: T
  description: D
  contact_email: hi@example.com
  copyright_holder: Telly
stores:
  app_store: null
  play_store: https://play.google.com/store/apps/details?id=x
hero: {eyebrow: E, headline: H, tagline: T, body: B, screenshot: duel}
features:
  - {id: a, eyebrow: E, title: T, body: B, accent: phosphorLime, screenshot: feed, points: [one, two]}
gallery: {title: G, body: B, items: [{screenshot: canon, caption: C}]}
cta: {title: C, body: B}
''';

void main() {
  group('WEB-03: site/content.yaml', () {
    test('parses stores, features, gallery and the base path', () {
      final c = parseSiteContent(_minimal);
      expect(c.stores.appStore, isNull);
      expect(c.stores.playStore, startsWith('https://play.google.com'));
      expect(c.features.single.points, ['one', 'two']);
      expect(c.screenshots, {'duel', 'feed', 'canon'});
      expect(c.basePath, '/Telly/');
    });

    test('rejects missing fields, bad URLs, bad emails and non-https store links', () {
      expect(() => parseSiteContent(_minimal.replaceFirst('headline: H, ', '')), throwsA(isA<SiteContentError>()));
      expect(
        () => parseSiteContent(_minimal.replaceFirst('https://example.com/Telly/', 'example.com')),
        throwsA(isA<SiteContentError>()),
      );
      expect(() => parseSiteContent(_minimal.replaceFirst('hi@example.com', 'nope')), throwsA(isA<SiteContentError>()));
      expect(
        () => parseSiteContent(_minimal.replaceFirst('https://play.google', 'http://play.google')),
        throwsA(isA<SiteContentError>()),
      );
    });

    test('fails when a screenshot has no scene or an accent is not a theme token', () {
      final c = parseSiteContent(_minimal);
      expect(
        () => validateAgainstApp(c, screenshots: {'duel', 'feed'}, colorTokens: {'phosphorLime'}),
        throwsA(isA<SiteContentError>().having((e) => e.message, 'message', contains('canon'))),
      );
      expect(
        () => validateAgainstApp(c, screenshots: {'duel', 'feed', 'canon'}, colorTokens: {'neonCoral'}),
        throwsA(isA<SiteContentError>()),
      );
    });

    test('the real content only uses existing scenes and color tokens', () {
      final content = parseSiteContent(File('site/content.yaml').readAsStringSync());
      final colors = parseColorTokens(File('lib/core/theme/telly_colors.dart').readAsStringSync());
      validateAgainstApp(
        content,
        screenshots: {for (final s in siteScenes) s.id},
        colorTokens: {for (final c in colors) c.name},
      );
      expect(content.contactEmail, 'karlandraos@gmail.com');
    });
  });
}
