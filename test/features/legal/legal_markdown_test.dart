import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/legal/domain/legal_markdown.dart';

void main() {
  group('FE-AUTH-04: parseLegalMarkdown', () {
    test('splits headings, rules, nested bullets and wrapped paragraphs', () {
      final blocks = parseLegalMarkdown('''
# Title
*Last Updated*

First line
continues here.

---

## Section
- Top item
  - Nested item
''');

      expect(blocks, hasLength(7));
      expect((blocks[0] as LegalHeading).level, 1);
      expect((blocks[0] as LegalHeading).text, 'Title');
      expect((blocks[1] as LegalParagraph).text, '*Last Updated*');
      expect((blocks[2] as LegalParagraph).text, 'First line continues here.');
      expect(blocks[3], isA<LegalDivider>());
      expect((blocks[4] as LegalHeading).level, 2);
      expect((blocks[5] as LegalBullet).depth, 0);
      expect((blocks[6] as LegalBullet).depth, 1);
      expect((blocks[6] as LegalBullet).text, 'Nested item');
    });

    test('replaces LaTeX arrows with glyphs', () {
      final blocks = parseLegalMarkdown(r'Go to **Settings $\rightarrow$ Delete Account**.');
      expect((blocks.single as LegalParagraph).text, 'Go to **Settings → Delete Account**.');
    });

    test('every bundled legal document parses into headed content', () {
      for (final doc in LegalDocument.values) {
        final blocks = parseLegalMarkdown(File(doc.assetPath).readAsStringSync());
        expect(blocks.first, isA<LegalHeading>(), reason: doc.name);
        expect(blocks.whereType<LegalBullet>(), isNotEmpty, reason: doc.name);
        expect(blocks.whereType<LegalParagraph>().any((p) => p.text.contains(r'$')), isFalse, reason: doc.name);
      }
    });
  });

  group('FE-AUTH-04: parseLegalInlines', () {
    test('styles bold, italic and code runs and keeps plain text between them', () {
      final runs = parseLegalInlines('A **bold** and *soft* `mail@x` end');
      expect(runs.map((r) => r.style), [
        LegalInlineStyle.plain,
        LegalInlineStyle.bold,
        LegalInlineStyle.plain,
        LegalInlineStyle.italic,
        LegalInlineStyle.plain,
        LegalInlineStyle.code,
        LegalInlineStyle.plain,
      ]);
      expect(runs.map((r) => r.text).join(), 'A bold and soft mail@x end');
    });

    test('unclosed markers stay literal', () {
      final runs = parseLegalInlines('5 * 3 = **15');
      expect(runs.single.style, LegalInlineStyle.plain);
      expect(runs.single.text, '5 * 3 = **15');
    });
  });
}
