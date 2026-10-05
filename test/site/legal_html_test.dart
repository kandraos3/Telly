import 'dart:io';

import 'package:test/test.dart';

import '../../tool/site/src/legal_html.dart';

void main() {
  group('WEB-03: legal Markdown to HTML', () {
    test('title, headings, paragraphs, rules and nested bullets', () {
      final doc = legalDocumentHtml('# Privacy\nIntro **bold** and *soft*.\n\n## 1. Data\n- One\n  - Nested\n- Two\n---\n');
      expect(doc.title, 'Privacy');
      expect(doc.html, contains('<p>Intro <strong>bold</strong> and <em>soft</em>.</p>'));
      expect(doc.html, contains('<h2>1. Data</h2>'));
      expect(doc.html, contains('<ul><li>One<ul><li>Nested</li></ul>\n</li><li>Two</li></ul>'));
      expect(doc.html, contains('<hr>'));
    });

    test('escapes HTML and links email addresses', () {
      expect(legalInlineHtml('a <b> & `x@y.com`'), 'a &lt;b&gt; &amp; <a href="mailto:x@y.com">x@y.com</a>');
      expect(legalInlineHtml('`code`'), '<code>code</code>');
    });

    test('both bundled documents render with a title and the contact address', () {
      for (final path in ['docs/legal/PRIVACY_POLICY.md', 'docs/legal/TERMS_OF_SERVICE.md']) {
        final doc = legalDocumentHtml(File(path).readAsStringSync());
        expect(doc.title, isNotEmpty, reason: path);
        expect(doc.html, contains('mailto:karlandraos@gmail.com'), reason: path);
        expect(doc.html, isNot(contains(r'$\rightarrow$')), reason: path);
      }
    });
  });
}
