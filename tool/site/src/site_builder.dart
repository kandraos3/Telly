// Assembles build/site/ from site/, the generated tokens and screenshots, and
// docs/legal/ (WEB-03). Fails loudly instead of publishing a broken page.
import 'dart:convert';
import 'dart:io';

import 'content.dart';
import 'pages.dart';
import 'tokens.dart';

class SiteBuildError implements Exception {
  final String message;
  SiteBuildError(this.message);
  @override
  String toString() => 'Site build failed: $message';
}

/// Custom properties every page may define inline (`style="--accent: …"`).
final _hexColor = RegExp(r'#[0-9a-fA-F]{3,8}\b');
final _rgbLiteral = RegExp(r'rgba?\(\s*\d');
final _varRef = RegExp(r'var\(\s*(--[\w-]+)');

/// Problems in hand-written CSS: color literals (colors must come from the app
/// tokens) and `var()` references nothing defines.
List<String> cssViolations(String css, Set<String> defined) {
  final problems = <String>[];
  final withoutComments = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  for (final (i, line) in withoutComments.split('\n').indexed) {
    for (final m in _hexColor.allMatches(line)) {
      problems.add('line ${i + 1}: color literal ${m[0]}; use a token from tokens.css');
    }
    if (_rgbLiteral.hasMatch(line)) {
      problems.add('line ${i + 1}: rgb() literal; use rgba(var(--token-rgb), alpha)');
    }
  }
  for (final m in _varRef.allMatches(withoutComments)) {
    if (!defined.contains(m[1])) problems.add('undefined custom property ${m[1]}');
  }
  return problems;
}

/// Internal links and assets in [pages] (output path → HTML) that point at no
/// file in [files] (output paths). [basePath] is the site's URL path (`/Telly/`).
List<String> brokenLinks(Map<String, String> pages, Set<String> files, String basePath) {
  final problems = <String>[];
  final attr = RegExp(r'''(?:href|src)="([^"]*)"''');
  for (final MapEntry(key: page, value: html) in pages.entries) {
    final dir = page.contains('/') ? page.substring(0, page.lastIndexOf('/') + 1) : '';
    for (final m in attr.allMatches(html)) {
      var target = m[1]!;
      if (target.startsWith('http') || target.startsWith('mailto:') || target.startsWith('#')) continue;
      target = target.split('#').first;
      final resolved = target.startsWith(basePath)
          ? Uri.parse('/${target.substring(basePath.length)}')
          : Uri.parse('/$dir').resolve(target.isEmpty ? './' : target);
      var path = resolved.path.substring(1);
      if (path.isEmpty || path.endsWith('/')) path = '${path}index.html';
      if (!files.contains(path)) problems.add('$page → ${m[1]} (no $path)');
    }
  }
  return problems;
}

/// FNV-1a over every file's path and bytes, so the deploy can tell an
/// unchanged site from a changed one.
String contentHash(Map<String, List<int>> files) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final path in files.keys.toList()..sort()) {
    for (final byte in [...utf8.encode(path), 0, ...files[path]!, 0]) {
      hash = (hash ^ byte) * prime;
    }
  }
  // Dart ints are signed 64-bit: print the two 32-bit halves unsigned.
  String half(int h) => h.toRadixString(16).padLeft(8, '0');
  return half((hash >> 32) & 0xffffffff) + half(hash & 0xffffffff);
}

/// Builds the site into [outDir]. Paths are relative to the repo root.
void buildSite({String genDir = 'build/site_gen', String outDir = 'build/site', int? year}) {
  final tokensFile = File('$genDir/tokens.css');
  final shotsDir = Directory('$genDir/screenshots');
  if (!tokensFile.existsSync() || !shotsDir.existsSync()) {
    throw SiteBuildError('$genDir is missing; run `flutter test tool/site/generate_site_test.dart` first');
  }

  final content = parseSiteContent(File('site/content.yaml').readAsStringSync());
  final colors = parseColorTokens(File('lib/core/theme/telly_colors.dart').readAsStringSync());
  final screenshots = {
    for (final f in shotsDir.listSync().whereType<File>())
      if (f.path.endsWith('.png')) f.uri.pathSegments.last.replaceAll('.png', ''),
  };
  validateAgainstApp(content, screenshots: screenshots, colorTokens: {for (final c in colors) c.name});

  final themeColor = colors.firstWhere((c) => c.name == 'backgroundPrimary').css;
  final ctx = PageContext(content: content, root: '', themeColor: themeColor, year: year ?? DateTime.now().year);
  final pages = <String, String>{
    'index.html': landingPage(ctx),
    'privacy/index.html':
        legalPage(ctx.at('../'), markdown: File('docs/legal/PRIVACY_POLICY.md').readAsStringSync(), path: 'privacy/'),
    'terms/index.html':
        legalPage(ctx.at('../'), markdown: File('docs/legal/TERMS_OF_SERVICE.md').readAsStringSync(), path: 'terms/'),
    'support/index.html': supportPage(ctx.at('../')),
    '404.html': notFoundPage(ctx.at(content.basePath)),
  };

  final tokensCss = tokensFile.readAsStringSync();
  final siteCss = File('site/static/site.css').readAsStringSync();
  final defined = {
    ...definedCustomProperties(tokensCss),
    ...definedCustomProperties(siteCss),
    for (final html in pages.values) ...definedCustomProperties(html),
  };
  final problems = [
    ...cssViolations(siteCss, defined).map((p) => 'site.css $p'),
    for (final MapEntry(key: page, value: html) in pages.entries)
      for (final m in _varRef.allMatches(html))
        if (!defined.contains(m[1])) '$page: undefined custom property ${m[1]}',
  ];

  final files = <String, List<int>>{
    for (final MapEntry(key: path, value: html) in pages.entries) path: utf8.encode(html),
    'assets/tokens.css': utf8.encode(tokensCss),
    'assets/site.css': utf8.encode(siteCss),
    'assets/icon.png': File('assets/brand/icon_1024.png').readAsBytesSync(),
    for (final f in Directory('$genDir/fonts').listSync().whereType<File>())
      'assets/fonts/${f.uri.pathSegments.last}': f.readAsBytesSync(),
    for (final id in content.screenshots) 'assets/screenshots/$id.png': File('${shotsDir.path}/$id.png').readAsBytesSync(),
    for (final f in Directory('site/static').listSync(recursive: true).whereType<File>())
      if (!f.path.endsWith('site.css'))
        f.path.replaceAll(r'\', '/').replaceFirst('site/static/', ''): f.readAsBytesSync(),
    '.nojekyll': const [],
  };
  problems.addAll(brokenLinks(pages, files.keys.toSet(), content.basePath));
  if (problems.isNotEmpty) throw SiteBuildError('\n  ${problems.join('\n  ')}');

  _removeStale(Directory(outDir), {...files.keys, 'build-hash.txt'});
  for (final MapEntry(key: path, value: bytes) in files.entries) {
    File('$outDir/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
  File('$outDir/build-hash.txt').writeAsStringSync('${contentHash(files)}\n');
}

/// Removes files in [dir] that the new build doesn't write. Directories are
/// left in place: on Windows they can be flagged read-only or briefly held by a
/// scanner, and an empty folder is harmless.
void _removeStale(Directory dir, Set<String> keep) {
  if (!dir.existsSync()) return;
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    final rel = file.path.replaceAll(r'\', '/').substring(dir.path.length + 1);
    if (!keep.contains(rel)) file.deleteSync();
  }
}
