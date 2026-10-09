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
hero:
  eyebrow: E
  headline: H
  tagline: T
  body: B
  duel: {media_type: tv, total: 40, pairs: [[Breaking Bad, The Sopranos], [The Wire, Breaking Bad]]}
chapters:
  - {id: track, name: Track, summary: S, title: T, body: B, accent: phosphorLime, screenshots: [home, watching],
     cards: [{title: Tonight, body: B}]}
  - {id: rank, name: Rank, summary: S, title: T, body: B, accent: warmAmber, screenshots: [canon], points: [one, two],
     show_tiers: true}
cta: {title: C, body: B}
''';

void main() {
  group('WEB-03: site/content.yaml', () {
    test('parses stores, chapters, the duel and the base path', () {
      final c = parseSiteContent(_minimal);
      expect(c.stores.appStore, isNull);
      expect(c.stores.playStore, startsWith('https://play.google.com'));
      expect(c.chapters.map((ch) => ch.id), ['track', 'rank']);
      expect(c.chapters.first.cards.single.title, 'Tonight');
      expect(c.chapters.last.points, ['one', 'two']);
      expect(c.chapters.last.showTiers, isTrue);
      expect(c.screenshots, {'home', 'watching', 'canon'});
      expect(c.accents, {'phosphorLime', 'warmAmber'});
      expect(c.basePath, '/Telly/');
    });

    test('#263: the duel keeps its pairs in order and lists each title once', () {
      final duel = parseSiteContent(_minimal).duel;
      expect(duel.mediaType, 'tv');
      expect(duel.total, 40);
      expect(duel.pairs, [('Breaking Bad', 'The Sopranos'), ('The Wire', 'Breaking Bad')]);
      expect(duel.titles, ['Breaking Bad', 'The Sopranos', 'The Wire']);
      expect(posterSlug('Breaking Bad'), 'breaking-bad');
      expect(posterSlug("Grey's Anatomy: Season 2!"), 'grey-s-anatomy-season-2');
    });

    test('#263: rejects a duel without pairs, a lopsided pair, a mixed ranking or a tiny total', () {
      const pairs = 'pairs: [[Breaking Bad, The Sopranos], [The Wire, Breaking Bad]]';
      for (final (from, to) in [
        (pairs, 'pairs: []'),
        ('[The Wire, Breaking Bad]', '[The Wire]'),
        ('[The Wire, Breaking Bad]', '[The Wire, The Wire]'),
        ('media_type: tv', 'media_type: anime'),
        ('total: 40', 'total: 1'),
      ]) {
        expect(() => parseSiteContent(_minimal.replaceFirst(from, to)), throwsA(isA<SiteContentError>()), reason: to);
      }
    });

    test('#262: rejects bad or duplicate chapter ids, no or three screenshots, and no chapters', () {
      expect(() => parseSiteContent(_minimal.replaceFirst('id: rank', 'id: track')), throwsA(isA<SiteContentError>()));
      expect(() => parseSiteContent(_minimal.replaceFirst('id: rank', 'id: Rank Two')), throwsA(isA<SiteContentError>()));
      expect(() => parseSiteContent(_minimal.replaceFirst('screenshots: [canon]', 'screenshots: []')),
          throwsA(isA<SiteContentError>()));
      expect(() => parseSiteContent(_minimal.replaceFirst('screenshots: [canon]', 'screenshots: [a, b, c]')),
          throwsA(isA<SiteContentError>()));
      final start = _minimal.indexOf('chapters:');
      final end = _minimal.indexOf('cta:');
      expect(() => parseSiteContent('${_minimal.substring(0, start)}chapters: []\n${_minimal.substring(end)}'),
          throwsA(isA<SiteContentError>()));
    });

    test('rejects missing fields, bad URLs, bad emails and non-https store links', () {
      expect(() => parseSiteContent(_minimal.replaceFirst('  headline: H\n', '')), throwsA(isA<SiteContentError>()));
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
        () => validateAgainstApp(c, screenshots: {'home', 'watching'}, colorTokens: {'phosphorLime', 'warmAmber'}),
        throwsA(isA<SiteContentError>().having((e) => e.message, 'message', contains('canon'))),
      );
      expect(
        () => validateAgainstApp(c, screenshots: {'home', 'watching', 'canon'}, colorTokens: {'phosphorLime'}),
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
      expect(content.chapters.map((c) => c.id), ['track', 'rank', 'discover', 'friends', 'play']);
      expect(content.chapters.every((c) => c.screenshots.length == 2), isTrue);
      expect(content.duel.mediaType, 'tv');
    });
  });
}
