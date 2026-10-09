import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

import '../../tool/site/src/content.dart';
import '../../tool/site/src/pages.dart';
import '../../tool/site/src/site_builder.dart';
import '../../tool/site/src/tokens.dart';
import '../../tool/site/src/typography_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final content = parseSiteContent(File('site/content.yaml').readAsStringSync());
  PageContext ctx([String root = '']) => PageContext(content: content, root: root, themeColor: '#08090c', year: 2026);

  group('WEB-03: CSS guard', () {
    test('rejects color literals and undefined custom properties', () {
      final problems = cssViolations(
        'a { color: #fff; background: rgb(1, 2, 3); border-color: var(--nope); }\n'
        '/* #abc in a comment is fine */ b { color: rgba(var(--ok-rgb), 0.2); }',
        {'--ok-rgb'},
      );
      expect(problems, hasLength(3));
      expect(problems.join(), allOf(contains('#fff'), contains('rgb()'), contains('--nope')));
    });

    test('site.css uses only tokens generated from the app theme', () {
      final tokens = buildTokensCss(
        colors: parseColorTokens(File('lib/core/theme/telly_colors.dart').readAsStringSync()),
        type: tellyTypeTokens(),
        fonts: const [],
      );
      final siteCss = File('site/static/site.css').readAsStringSync();
      final defined = {
        ...definedCustomProperties(tokens),
        ...definedCustomProperties(siteCss),
        ...definedCustomProperties(landingPage(ctx())),
      };
      expect(cssViolations(siteCss, defined), isEmpty);
    });
  });

  group('WEB-03: pages', () {
    test('#262: landing page has the chapter nav, the strip and every chapter with its screenshots', () {
      final html = landingPage(ctx());
      for (final (i, ch) in content.chapters.indexed) {
        expect(html, contains('<section class="chapter${i.isOdd ? ' chapter--flip' : ''}" id="${ch.id}"'));
        expect(html, contains('<a class="nav__chapter" href="#${ch.id}">${ch.name}</a>'));
        expect(html, contains('<a class="strip__item" href="#${ch.id}"'));
        expect(html, contains('0${i + 1} · ${ch.name}'));
        for (final id in ch.screenshots) {
          expect(html, contains('assets/screenshots/$id.png'));
        }
      }
      expect('phone--second'.allMatches(html), hasLength(content.chapters.length));
      expect(html, contains('God Tier'));
      expect(html, contains('9.20 – 10.00'));
      expect(html, contains('store--soon'));
      expect(html, contains('Coming soon to'));
      expect(html, isNot(contains('id="features"')), reason: 'the eight-row feature list is gone');
    });

    test('#263: the hero duel renders the first pair, the explanation and its data for site.js', () {
      final html = landingPage(ctx());
      final (a, b) = content.duel.pairs.first;
      expect(html, contains('<script src="assets/site.js" defer></script>'));
      expect(html, contains('<span class="duel__title">$a</span>'));
      expect(html, contains('<span class="duel__title">$b</span>'));
      expect(html, contains('assets/posters/${posterSlug(a)}.png'));
      expect(html, contains('Too close to call'));
      expect(html, contains('A few of these after each watch'));

      final raw = RegExp(r'data-duel="([^"]*)"').firstMatch(html)![1]!;
      final data = jsonDecode(raw.replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&'))
          as Map<String, dynamic>;
      expect(data['media'], 'TV');
      expect(data['label'], 'Example scores in a ranking of ${content.duel.total} shows');
      expect(data['pairs'], hasLength(content.duel.pairs.length));
      expect((data['pairs'] as List).first[1], {'title': b, 'poster': 'assets/posters/${posterSlug(b)}.png'});
      final (first, second) = duelScores(content.duel);
      expect(data['scores'], [first.toStringAsFixed(2), second.toStringAsFixed(2)]);
    });

    test('#263: duel scores come from the app score curve, first above second', () {
      final (first, second) = duelScores(content.duel);
      expect(first, ScoreCurveCalculator.calculateRoundedScore(1, content.duel.total));
      expect(second, ScoreCurveCalculator.calculateRoundedScore(2, content.duel.total));
      expect(first, greaterThan(second));
    });

    test('only the landing page loads the script', () {
      expect(supportPage(ctx('../')), isNot(contains('site.js')));
    });

    test('a store link switches its badge on', () {
      final live = parseSiteContent(File('site/content.yaml')
          .readAsStringSync()
          .replaceFirst('app_store: null', 'app_store: https://apps.apple.com/app/id123'));
      final html = landingPage(PageContext(content: live, root: '', themeColor: '#000', year: 2026));
      expect(html, contains('<a class="store" href="https://apps.apple.com/app/id123"'));
      expect(html, contains('Download on the'));
      // Only Google Play is still a placeholder, in the hero and the closing CTA.
      expect('class="store store--soon"'.allMatches(html), hasLength(2));
    });

    test('footer carries copyright, data-provider attribution and trademark notices', () {
      final html = supportPage(ctx('../'));
      expect(html, contains('© 2026 Telly'));
      expect(html, contains('not endorsed or certified by TMDB'));
      expect(html, contains('JustWatch'));
      expect(html, contains('AniList'));
      expect(html, contains('Google Play is a trademark of Google LLC'));
      expect(html, contains('SIL Open Font License'));
      expect(html, contains('mailto:karlandraos@gmail.com'));
      expect(html, contains('Delete Account'));
    });

    test('legal pages render the bundled documents with a canonical URL', () {
      final html = legalPage(
        ctx('../'),
        markdown: File('docs/legal/PRIVACY_POLICY.md').readAsStringSync(),
        path: 'privacy/',
      );
      expect(html, contains('Privacy Policy</h1>'));
      expect(html, contains('<link rel="canonical" href="https://kandraos3.github.io/Telly/privacy/">'));
    });
  });

  group('WEB-03: link check and hash', () {
    test('resolves relative, root and base-path links', () {
      final files = {'index.html', 'privacy/index.html', 'assets/site.css'};
      final pages = {
        'index.html': '<a href="./"></a><a href="privacy/"></a><a href="#x"></a><a href="mailto:a@b.c"></a>',
        'privacy/index.html': '<a href="../"></a><link href="../assets/site.css"><a href="../terms/"></a>',
        '404.html': '<a href="/Telly/"></a><img src="/Telly/assets/missing.png">',
      };
      expect(brokenLinks(pages, files, '/Telly/'), [
        'privacy/index.html → ../terms/ (no terms/index.html)',
        '404.html → /Telly/assets/missing.png (no assets/missing.png)',
      ]);
    });

    test('content hash is stable and changes with content', () {
      final a = contentHash({
        'a': [1, 2],
        'b': [3],
      });
      expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(
        contentHash({
          'b': [3],
          'a': [1, 2],
        }),
        a,
      );
      expect(
        contentHash({
          'a': [1, 2],
          'b': [4],
        }),
        isNot(a),
      );
    });
  });
}
