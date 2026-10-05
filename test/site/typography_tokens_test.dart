import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../tool/site/src/tokens.dart';
import '../../tool/site/src/typography_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('WEB-01: live TellyTypography export', () {
    test('every style declared in telly_typography.dart is exported to the site', () {
      final declared = parseTypographyStyleNames(File('lib/core/theme/telly_typography.dart').readAsStringSync());
      expect(
        tellyTypeStyles.keys.toSet(),
        declared.toSet(),
        reason: 'Add new TellyTypography styles to tellyTypeStyles in tool/site/src/typography_tokens.dart',
      );
    });

    test('reads family, size, weight, line height, tracking and figures from the TextStyle', () {
      final tokens = {for (final t in tellyTypeTokens()) t.name: t};
      final display = tokens['displayXXL']!;
      expect(display.family, 'PlayfairDisplay');
      expect(display.size, 38);
      expect(display.weight, 700);
      expect(display.height, closeTo(44 / 38, 1e-9));
      expect(display.letterSpacing, closeTo(-0.03 * 38, 1e-9));
      expect(tokens['bodyLarge']!.family, 'PlusJakartaSans');
      expect(tokens['scoreMono']!.family, 'JetBrainsMono');
      expect(tokens['scoreChip']!.tabularFigures, isTrue);
      expect(tokens['bodyLarge']!.tabularFigures, isFalse);
    });
  });
}
