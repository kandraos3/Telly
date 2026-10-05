// docs/legal/*.md → HTML with the app's own legal Markdown parser (WEB-03), so
// the site and the in-app viewer (FE-AUTH-04) always show the same text.
import 'package:telly_app/features/legal/domain/legal_markdown.dart';

String escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

/// Inline runs as HTML; email addresses become mailto links.
String legalInlineHtml(String text) {
  final out = StringBuffer();
  for (final run in parseLegalInlines(text)) {
    final escaped = escapeHtml(run.text);
    final linked = escaped.replaceAllMapped(_email, (m) => '<a href="mailto:${m[0]}">${m[0]}</a>');
    out.write(switch (run.style) {
      LegalInlineStyle.plain => linked,
      LegalInlineStyle.bold => '<strong>$linked</strong>',
      LegalInlineStyle.italic => '<em>$linked</em>',
      LegalInlineStyle.code => _email.hasMatch(run.text) ? linked : '<code>$escaped</code>',
    });
  }
  return out.toString();
}

/// The document's `#` title and its body as HTML (title excluded).
({String title, String html}) legalDocumentHtml(String markdown) {
  final blocks = parseLegalMarkdown(markdown);
  var title = '';
  final out = StringBuffer();
  var depth = -1; // open <ul> nesting, -1 = none

  void closeLists([int to = -1]) {
    while (depth > to) {
      out.writeln('</li></ul>');
      depth--;
    }
  }

  for (final block in blocks) {
    if (block is LegalBullet) {
      final target = block.depth.clamp(0, depth + 1);
      if (target > depth) {
        out.write('<ul><li>');
        depth = target;
      } else {
        closeLists(target);
        out.write('</li><li>');
      }
      out.write(legalInlineHtml(block.text));
      continue;
    }
    closeLists();
    switch (block) {
      case LegalHeading(level: 1) when title.isEmpty:
        title = block.text;
      case LegalHeading():
        final level = block.level.clamp(2, 4);
        out.writeln('<h$level>${legalInlineHtml(block.text)}</h$level>');
      case LegalParagraph():
        out.writeln('<p>${legalInlineHtml(block.text)}</p>');
      case LegalDivider():
        out.writeln('<hr>');
      case LegalBullet():
        break;
    }
  }
  closeLists();
  return (title: title, html: out.toString());
}
