import 'dart:io';

import 'package:test/test.dart';

import '../../tool/site/src/tokens.dart';

void main() {
  group('WEB-01: color tokens from TellyColors', () {
    test('parses opaque and translucent constants and skips Day Cathode tokens', () {
      const source = '''
        static const Color backgroundPrimary = Color(0xFF08090C); // Void Canvas
        static const Color borderGlass = Color(0x14FFFFFF);
        static const Color lightTextPrimary = Color(0xFF0F1117);
        static Color canvasOf(BuildContext context) => backgroundPrimary;
      ''';
      final tokens = parseColorTokens(source);
      expect(tokens.map((t) => t.name), ['backgroundPrimary', 'borderGlass']);
      expect(tokens[0].css, '#08090c');
      expect(tokens[1].css, 'rgba(255, 255, 255, 0.078)');
    });

    test('reads every dark token of the real theme, including the style guide anchors', () {
      final tokens = {
        for (final t in parseColorTokens(File('lib/core/theme/telly_colors.dart').readAsStringSync())) t.name: t.css,
      };
      expect(tokens['backgroundPrimary'], '#08090c');
      expect(tokens['phosphorLime'], '#d2ff52');
      expect(tokens['neonCoral'], '#ff4b6e');
      expect(tokens['warmAmber'], '#ffa733');
      expect(tokens['electricViolet'], '#7c5cff');
      expect(tokens['tierGodStart'], '#ffe066');
      expect(tokens.keys.where((k) => k.startsWith('light')), isEmpty);
    });

    test('names become kebab-case custom properties with an rgb triplet', () {
      final css = buildTokensCss(colors: const [ColorToken('phosphorLime', 0xFFD2FF52)], type: const [], fonts: const []);
      expect(css, contains('--phosphor-lime: #d2ff52;'));
      expect(css, contains('--phosphor-lime-rgb: 210, 255, 82;'));
    });
  });

  group('WEB-01: typography and fonts', () {
    test('kebab handles acronyms', () {
      expect(kebab('displayXXL'), 'display-xxl');
      expect(kebab('scoreHero'), 'score-hero');
      expect(kebab('tierGodStart'), 'tier-god-start');
    });

    test('a text style becomes custom properties and a utility class with em tracking', () {
      final css = buildTokensCss(
        colors: const [],
        fonts: const [],
        type: const [
          TypeToken(
            name: 'displayXXL',
            family: 'PlayfairDisplay',
            size: 38,
            weight: 700,
            height: 44 / 38,
            letterSpacing: -0.03 * 38,
          ),
          TypeToken(name: 'scoreChip', family: 'PlusJakartaSans', size: 14, weight: 700, tabularFigures: true),
        ],
      );
      expect(css, contains('--t-display-xxl-size: 38px;'));
      expect(css, contains('--t-display-xxl-weight: 700;'));
      expect(css, contains('--t-display-xxl-line-height: 1.158;'));
      expect(css, contains('--t-display-xxl-tracking: -0.03em;'));
      expect(css, contains("--font-playfair-display: 'PlayfairDisplay', Georgia"));
      expect(css, contains('.t-display-xxl {'));
      expect(css, contains('--t-score-chip-line-height: normal;'));
      expect(RegExp(r'\.t-score-chip \{[^}]*tabular-nums').hasMatch(css), isTrue);
    });

    test('bundled font files become @font-face rules', () {
      expect(parseFontFile('PlusJakartaSans-SemiBold.ttf')?.weight, 600);
      expect(parseFontFile('README.md'), isNull);
      final css = buildTokensCss(
        colors: const [],
        type: const [],
        fonts: const [FontFace('JetBrainsMono', 500, 'JetBrainsMono-Medium.ttf')],
      );
      expect(css, contains("src: url('fonts/JetBrainsMono-Medium.ttf') format('truetype');"));
      expect(css, contains('font-weight: 500;'));
    });

    test('lists declared style names and defined custom properties', () {
      expect(
        parseTypographyStyleNames('static TextStyle bodyLarge({Color c}) => x; static TextStyle _p() => y;'),
        ['bodyLarge'],
      );
      expect(definedCustomProperties(':root { --a: 1; --b-c: var(--a); }'), {'--a', '--b-c'});
    });

    test('type tokens survive a JSON round trip', () {
      const t = TypeToken(name: 'caption', family: 'PlusJakartaSans', size: 11, weight: 500, height: 15 / 11);
      final back = TypeToken.fromJson(t.toJson());
      expect(back.size, 11);
      expect(back.height, closeTo(15 / 11, 1e-9));
      expect(back.tabularFigures, isFalse);
    });
  });
}
