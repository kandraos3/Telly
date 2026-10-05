/// The bundled legal documents (`docs/legal/`), rendered in-app until the web pages are hosted.
enum LegalDocument {
  terms('Terms of Service', 'docs/legal/TERMS_OF_SERVICE.md'),
  privacy('Privacy Policy', 'docs/legal/PRIVACY_POLICY.md');

  final String title;
  final String assetPath;

  const LegalDocument(this.title, this.assetPath);
}

sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  final int level;
  final String text;
  const LegalHeading(this.level, this.text);
}

class LegalParagraph extends LegalBlock {
  final String text;
  const LegalParagraph(this.text);
}

class LegalBullet extends LegalBlock {
  final int depth;
  final String text;
  const LegalBullet(this.depth, this.text);
}

class LegalDivider extends LegalBlock {
  const LegalDivider();
}

enum LegalInlineStyle { plain, bold, italic, code }

class LegalInline {
  final String text;
  final LegalInlineStyle style;
  const LegalInline(this.text, this.style);
}

/// Parses the Markdown subset the legal docs use: `#`/`##` headings, `---` rules,
/// (nested) `-` bullets, paragraphs, and `**bold**` / `*italic*` / `` `code` `` inlines.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalParagraph(paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in _sanitize(source).split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (trimmed.isEmpty) {
      flush();
    } else if (RegExp(r'^-{3,}$').hasMatch(trimmed)) {
      flush();
      blocks.add(const LegalDivider());
    } else if (heading != null) {
      flush();
      blocks.add(LegalHeading(heading.group(1)!.length, heading.group(2)!));
    } else if (trimmed.startsWith('- ')) {
      flush();
      final indent = line.length - trimmed.length;
      blocks.add(LegalBullet(indent ~/ 2, trimmed.substring(2)));
    } else {
      paragraph.add(trimmed);
    }
  }
  flush();
  return blocks;
}

/// Splits inline emphasis into styled runs. Unclosed markers stay literal.
List<LegalInline> parseLegalInlines(String text) {
  final runs = <LegalInline>[];
  final pattern = RegExp(r'\*\*(\S(?:.*?\S)?)\*\*|`([^`]+)`|\*(\S(?:.*?\S)?)\*');
  var cursor = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > cursor) runs.add(LegalInline(text.substring(cursor, m.start), LegalInlineStyle.plain));
    if (m.group(1) != null) {
      runs.add(LegalInline(m.group(1)!, LegalInlineStyle.bold));
    } else if (m.group(2) != null) {
      runs.add(LegalInline(m.group(2)!, LegalInlineStyle.code));
    } else {
      runs.add(LegalInline(m.group(3)!, LegalInlineStyle.italic));
    }
    cursor = m.end;
  }
  if (cursor < text.length) runs.add(LegalInline(text.substring(cursor), LegalInlineStyle.plain));
  return runs;
}

/// Replaces the LaTeX arrows used in the docs with plain glyphs.
String _sanitize(String source) =>
    source.replaceAll(r'$\rightarrow$', '→').replaceAll(r'$\leftarrow$', '←').replaceAll('\r\n', '\n');
