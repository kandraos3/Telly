// HTML for every page of the Telly website (WEB-03; landing page: 05_WEBSITE, #254).
// Styling lives in site/static/site.css and uses only the tokens generated from
// the app; the hero duel's behaviour lives in site/static/site.js.
import 'dart:convert';

import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

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

String _layout(
  PageContext c, {
  required String title,
  required String description,
  required String path,
  required String body,
  bool script = false,
}) {
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
${script ? '<script src="${c.root}assets/site.js" defer></script>\n' : ''}</head>
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
${c.content.chapters.map((ch) => '      <a class="nav__chapter" href="${c.root}#${_e(ch.id)}">${_e(ch.name)}</a>').join('\n')}
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

/// Example scores for ranks 1 and 2 in a ranking of [Duel.total], from the app's own curve.
(double, double) duelScores(Duel duel) => (
      ScoreCurveCalculator.calculateRoundedScore(1, duel.total),
      ScoreCurveCalculator.calculateRoundedScore(2, duel.total),
    );

String _duelPick(PageContext c, String title, String pick) => '''<button type="button" class="duel__pick" data-pick="$pick">
          <img src="${c.root}assets/posters/${posterSlug(title)}.png" width="342" height="513" alt="" decoding="async">
          <span class="duel__title">${_e(title)}</span>
        </button>''';

/// The hero's playable duel (05_WEBSITE §2): the first pair, rendered so it reads without
/// JavaScript, plus everything site.js needs in `data-duel`.
String duelCard(PageContext c) {
  final duel = c.content.duel;
  final (first, second) = duelScores(duel);
  final noun = duel.mediaType == 'tv' ? 'shows' : 'films';
  final media = duel.mediaType == 'tv' ? 'TV' : 'Movies';
  final data = jsonEncode({
    'media': media,
    'label': 'Example scores in a ranking of ${duel.total} $noun',
    'scores': [first.toStringAsFixed(2), second.toStringAsFixed(2)],
    'pairs': [
      for (final (a, b) in duel.pairs)
        [
          for (final t in [a, b]) {'title': t, 'poster': '${c.root}assets/posters/${posterSlug(t)}.png'},
        ],
    ],
  });
  final (a, b) = duel.pairs.first;
  return '''<div class="duel" data-duel="${_e(data)}">
    <div class="duel__card" aria-live="polite">
      <div class="duel__head">
        <h2 class="duel__q" tabindex="-1">Which did you like more?</h2>
        <span class="duel__media">$media · Duel</span>
      </div>
      <div class="duel__pair">
        ${_duelPick(c, a, '0')}
        <span class="duel__vs" aria-hidden="true">vs</span>
        ${_duelPick(c, b, '1')}
      </div>
      <div class="duel__foot">
        <span class="duel__hint">Tap the one you liked more</span>
        <button type="button" class="duel__tie" data-pick="tie">Too close to call</button>
      </div>
    </div>
    <p class="duel__explain">That's a duel. A few of these after each watch and every title lands in its exact place, scored from 1.00 to 10.00.</p>
  </div>''';
}

/// What each screenshot shows, for its alt text.
const sceneAlt = {
  'home': "Telly Home: tonight's next episode, your moves and a weekly streak",
  'watching': 'Telly Watching: shows grouped by new episodes, in progress, finished and caught up',
  'reveal': 'Telly score reveal: The Bear lands at #2 in TV Rankings with 9.61',
  'canon': 'Telly TV Rankings with a podium for the top three',
  'explore': 'Telly Explore: picks and rows built from your rankings',
  'queue': "Telly Queue: saved shows with friends' scores and where they stream",
  'feed': "Telly Social: a friend's upset ranking with reactions",
  'taste-match': 'Telly friend profile with an 87% Taste Match',
  'achievements': 'Telly Achievements: pinned medals and collections in progress',
  'level': 'Telly Your level: level 12, a six-week streak and weekly quests',
};

String _number(int i) => (i + 1).toString().padLeft(2, '0');

String chapterSection(PageContext c, Chapter ch, int i) {
  final points = ch.points.isEmpty ? '' : '<ul class="points">${ch.points.map((p) => '<li>${_e(p)}</li>').join()}</ul>';
  final cards = ch.cards.isEmpty
      ? ''
      : '<ul class="cards">${ch.cards.map((x) => '<li class="card"><h3 class="h3">${_e(x.title)}</h3><p>${_e(x.body)}</p></li>').join()}</ul>';
  final shots = [
    for (final (j, id) in ch.screenshots.indexed)
      _phone(c, id, sceneAlt[id] ?? '${ch.name}: ${c.content.name} app screen', extraClass: j == 0 ? 'phone--lead' : 'phone--second'),
  ].join('\n  ');
  return '''<section class="chapter${i.isOdd ? ' chapter--flip' : ''}" id="${_e(ch.id)}" ${_accentStyle(ch.accent)}>
  <div class="chapter__text">
    <p class="eyebrow">${_number(i)} · ${_e(ch.name)}</p>
    <h2 class="h2">${_e(ch.title)}</h2>
    <p class="lead">${_e(ch.body)}</p>
    $points
    $cards
    ${ch.showTiers ? tierStrip() : ''}
  </div>
  <div class="chapter__shots${ch.screenshots.length > 1 ? ' chapter__shots--pair' : ''}">
  $shots
  </div>
</section>''';
}

String landingPage(PageContext c) {
  final s = c.content;
  final strip = [
    for (final (i, ch) in s.chapters.indexed)
      '<li><a class="strip__item" href="#${_e(ch.id)}" ${_accentStyle(ch.accent)}>'
          '<span class="strip__num">${_number(i)}</span>'
          '<span class="strip__name">${_e(ch.name)}</span>'
          '<span class="strip__sum">${_e(ch.summary)}</span></a></li>',
  ].join('\n    ');
  final chapters = [for (final (i, ch) in s.chapters.indexed) chapterSection(c, ch, i)].join('\n');
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
  ${duelCard(c)}
</section>

<nav class="wrap strip" aria-label="Chapters">
  <ol class="strip__list">
    $strip
  </ol>
</nav>

<div class="wrap">
$chapters
</div>

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
  return _layout(c, title: s.title, description: s.description, path: '', body: body, script: true);
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
