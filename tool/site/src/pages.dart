// HTML for every page of the Telly website (WEB-03). Styling lives in
// site/static/site.css and uses only the tokens generated from the app.
import 'package:telly_app/features/ranking/domain/canon_tier.dart';

import 'content.dart';
import 'legal_html.dart';

/// What a page needs besides the content.
class PageContext {
  final SiteContent content;

  /// Prefix from this page to the site root: '' at the root, '../' one level down,
  /// or the absolute base path for pages served at any depth (404).
  final String root;

  /// `--background-primary` as a literal, for `<meta name="theme-color">`.
  final String themeColor;
  final int year;

  const PageContext({required this.content, required this.root, required this.themeColor, required this.year});

  PageContext at(String root) => PageContext(content: content, root: root, themeColor: themeColor, year: year);
}

const _e = escapeHtml;

String _layout(PageContext c, {required String title, required String description, required String path, required String body}) {
  final s = c.content;
  final canonical = s.url.resolve(path);
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_e(title)}</title>
<meta name="description" content="${_e(description)}">
<meta name="theme-color" content="${c.themeColor}">
<meta name="color-scheme" content="dark">
<link rel="canonical" href="$canonical">
<meta property="og:type" content="website">
<meta property="og:site_name" content="${_e(s.name)}">
<meta property="og:title" content="${_e(title)}">
<meta property="og:description" content="${_e(description)}">
<meta property="og:url" content="$canonical">
<meta property="og:image" content="${s.url.resolve('assets/icon.png')}">
<meta name="twitter:card" content="summary">
<link rel="icon" type="image/png" href="${c.root}assets/icon.png">
<link rel="apple-touch-icon" href="${c.root}assets/icon.png">
<link rel="stylesheet" href="${c.root}assets/tokens.css">
<link rel="stylesheet" href="${c.root}assets/site.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${_nav(c)}
<main id="main">
$body
</main>
${_footer(c)}
</body>
</html>
''';
}

String _nav(PageContext c) => '''<header class="nav">
  <div class="wrap nav__inner">
    <a class="brand" href="${c.root.isEmpty ? './' : c.root}" aria-label="${_e(c.content.name)} home">
      <img src="${c.root}assets/icon.png" alt="" width="32" height="32">
      <span class="brand__word">telly</span>
    </a>
    <nav class="nav__links" aria-label="Main">
      <a href="${c.root}#features">Features</a>
      <a href="${c.root}support/">Support</a>
      <a class="nav__cta" href="${c.root}#download">Get the app</a>
    </nav>
  </div>
</header>''';

String _storeBadges(PageContext c) {
  String badge({required String store, required String? url, required String live, required String icon}) {
    final inner = '''<span class="store__icon" aria-hidden="true">$icon</span>
      <span class="store__text"><span class="store__small">${url == null ? 'Coming soon to' : live}</span><span class="store__name">$store</span></span>''';
    return url == null
        ? '<span class="store store--soon" aria-disabled="true">$inner</span>'
        : '<a class="store" href="${_e(url)}" rel="noopener">$inner</a>';
  }

  const phone =
      '<svg viewBox="0 0 24 24" width="22" height="22"><rect x="6" y="2" width="12" height="20" rx="3" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M10.5 18.5h3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>';
  const play =
      '<svg viewBox="0 0 24 24" width="22" height="22"><path d="M7 4.5v15l12-7.5z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>';
  final stores = c.content.stores;
  return '''<div class="stores">
    ${badge(store: 'App Store', url: stores.appStore, live: 'Download on the', icon: phone)}
    ${badge(store: 'Google Play', url: stores.playStore, live: 'Get it on', icon: play)}
  </div>''';
}

String _phone(PageContext c, String screenshot, String alt, {String extraClass = '', bool eager = false}) =>
    '''<figure class="phone $extraClass">
  <img src="${c.root}assets/screenshots/$screenshot.png" width="786" height="1704" alt="${_e(alt)}"${eager ? '' : ' loading="lazy"'} decoding="async">
</figure>''';

String _accentStyle(String token) {
  final name = token.replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => '-').toLowerCase();
  return 'style="--accent: var(--$name); --accent-rgb: var(--$name-rgb)"';
}

/// Score tiers from the app's `CanonTier`, colored with its tier tokens.
String tierStrip() {
  final chips = StringBuffer();
  for (final tier in CanonTier.values.where((t) => t != CanonTier.dropped)) {
    final palette = tier == CanonTier.lower ? 'dropped' : tier.name;
    chips.writeln(
      '<li class="tier" style="--tier-a: var(--tier-$palette-start); --tier-b: var(--tier-$palette-end)">'
      '<span class="tier__label">${_e(tier.label)}</span>'
      '<span class="tier__range">${_e(tier.rangeLabel)}</span></li>',
    );
  }
  return '<ul class="tiers" aria-label="Score tiers">\n$chips</ul>';
}

String landingPage(PageContext c) {
  final s = c.content;
  final features = StringBuffer();
  for (final (i, f) in s.features.indexed) {
    final points = f.points.isEmpty
        ? ''
        : '<ul class="points">${f.points.map((p) => '<li>${_e(p)}</li>').join()}</ul>';
    features.writeln('''<section class="feature${i.isOdd ? ' feature--flip' : ''}" id="${_e(f.id)}" ${_accentStyle(f.accent)}>
  <div class="feature__text">
    <p class="eyebrow">${_e(f.eyebrow)}</p>
    <h2 class="h2">${_e(f.title)}</h2>
    <p class="lead">${_e(f.body)}</p>
    $points
    ${f.showTiers ? tierStrip() : ''}
  </div>
  ${_phone(c, f.screenshot, '${f.title}: ${s.name} app screenshot')}
</section>''');
  }

  final gallery = s.gallery
      .map((g) => '<li class="gallery__item">${_phone(c, g.screenshot, '${g.caption} screen', extraClass: 'phone--small')}'
          '<p class="gallery__caption">${_e(g.caption)}</p></li>')
      .join('\n');
  final extras = s.extras
      .map((x) => '<li class="extra"><h3 class="h3">${_e(x.title)}</h3><p>${_e(x.body)}</p></li>')
      .join('\n');

  final body = '''<section class="hero wrap">
  <div class="hero__text">
    <p class="chip">${_e(s.heroEyebrow)}</p>
    <h1 class="h1">${_e(s.heroHeadline)}</h1>
    <p class="hero__tagline">${_e(s.heroTagline)}</p>
    <p class="lead">${_e(s.heroBody)}</p>
    ${_storeBadges(c)}
  </div>
  ${_phone(c, s.heroScreenshot, '${s.name} rankings screen: your ranked series with scores', extraClass: 'phone--hero', eager: true)}
</section>

<div class="wrap" id="features">
$features</div>

<section class="gallery" aria-labelledby="gallery-title">
  <div class="wrap">
    <h2 class="h2" id="gallery-title">${_e(s.galleryTitle)}</h2>
    <p class="lead">${_e(s.galleryBody)}</p>
  </div>
  <ul class="gallery__track">
$gallery
  </ul>
</section>

<section class="wrap">
  <ul class="extras">
$extras
  </ul>
</section>

<section class="wrap" id="download">
  <div class="cta">
    <h2 class="h2">${_e(s.ctaTitle)}</h2>
    <p class="lead">${_e(s.ctaBody)}</p>
    ${_storeBadges(c)}
  </div>
</section>''';
  return _layout(c, title: s.title, description: s.description, path: '', body: body);
}

String legalPage(PageContext c, {required String markdown, required String path}) {
  final doc = legalDocumentHtml(markdown);
  final body = '''<article class="wrap prose">
  <p class="eyebrow">Legal</p>
  <h1 class="h1 h1--page">${_e(doc.title)}</h1>
  <p class="meta">Also in the app under Settings.</p>
  ${doc.html}
</article>''';
  return _layout(
    c,
    title: '${doc.title} · ${c.content.name}',
    description: '${doc.title} for the ${c.content.name} app.',
    path: path,
    body: body,
  );
}

String supportPage(PageContext c) {
  final s = c.content;
  final mail = _e(s.contactEmail);
  final body = '''<article class="wrap prose">
  <p class="eyebrow">Support</p>
  <h1 class="h1 h1--page">How can we help?</h1>
  <p class="lead">Questions, bug reports, feature ideas or privacy requests: email us and a real person will reply.</p>
  <p><a class="button" href="mailto:$mail">$mail</a></p>
  <h2>Delete your account</h2>
  <p>In the app, open <strong>Settings → Delete Account…</strong>. Your account is deactivated straight away and permanently deleted after 30 days. If you can't sign in any more, email <a href="mailto:$mail">$mail</a> from the address on your account and we'll delete it for you.</p>
  <h2>Export your data</h2>
  <p>Open <strong>Settings → Data &amp; Exports</strong> to download your rankings as CSV, or your movies in Letterboxd format.</p>
  <h2>Legal</h2>
  <ul>
    <li><a href="${c.root}privacy/">Privacy Policy</a></li>
    <li><a href="${c.root}terms/">Terms of Service</a></li>
  </ul>
</article>''';
  return _layout(c, title: 'Support · ${s.name}', description: 'Contact ${s.name} support, delete your account or export your data.', path: 'support/', body: body);
}

String notFoundPage(PageContext c) => _layout(
      c,
      title: 'Page not found · ${c.content.name}',
      description: c.content.description,
      path: '404.html',
      body: '''<section class="wrap prose notfound">
  <p class="eyebrow">404</p>
  <h1 class="h1 h1--page">This page got dropped.</h1>
  <p class="lead">It isn't in our rankings any more.</p>
  <p><a class="button" href="${c.root}">Back to the home page</a></p>
</section>''',
    );

String _footer(PageContext c) {
  final s = c.content;
  return '''<footer class="footer">
  <div class="wrap footer__grid">
    <div>
      <a class="brand" href="${c.root.isEmpty ? './' : c.root}"><img src="${c.root}assets/icon.png" alt="" width="28" height="28"><span class="brand__word">telly</span></a>
      <p class="footer__tag">${_e(s.heroTagline)}</p>
    </div>
    <nav class="footer__links" aria-label="Footer">
      <a href="${c.root}privacy/">Privacy Policy</a>
      <a href="${c.root}terms/">Terms of Service</a>
      <a href="${c.root}support/">Support</a>
      <a href="mailto:${_e(s.contactEmail)}">${_e(s.contactEmail)}</a>
    </nav>
  </div>
  <div class="wrap footer__legal">
    <p>© ${c.year} ${_e(s.copyrightHolder)}. All rights reserved.</p>
    <p>This product uses the <a href="https://www.themoviedb.org/" rel="noopener">TMDB</a> API but is not endorsed or certified by TMDB. Streaming availability data is provided by <a href="https://www.justwatch.com/" rel="noopener">JustWatch</a> through TMDB. Anime imports use the <a href="https://anilist.co/" rel="noopener">AniList</a> API. Letterboxd imports read the export file you choose; ${_e(s.name)} is not affiliated with Letterboxd.</p>
    <p>Movie and series titles are trademarks of their respective owners. Poster art in the screenshots is generated for illustration. Emoji in the screenshots are <a href="https://github.com/mozilla/twemoji-colr" rel="noopener">Twemoji</a> (CC BY 4.0). Fonts: Plus Jakarta Sans, Playfair Display and JetBrains Mono, under the SIL Open Font License 1.1.</p>
    <p>Apple and App Store are trademarks of Apple Inc., registered in the U.S. and other countries. Google Play is a trademark of Google LLC.</p>
  </div>
</footer>''';
}
