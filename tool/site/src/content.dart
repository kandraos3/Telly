// site/content.yaml, parsed and validated (WEB-03; chapters and duel: 05_WEBSITE, #254).
import 'package:yaml/yaml.dart';

class SiteContentError implements Exception {
  final String message;
  SiteContentError(this.message);
  @override
  String toString() => 'site/content.yaml: $message';
}

class StoreLinks {
  final String? appStore;
  final String? playStore;
  const StoreLinks({this.appStore, this.playStore});
}

/// One section of the landing page (05_WEBSITE §3).
class Chapter {
  final String id;

  /// Short name for the nav and the chapter strip ("Track").
  final String name;

  /// One line for the chapter strip.
  final String summary;
  final String title;
  final String body;
  final String accent;

  /// One or two scene ids; the first is the lead.
  final List<String> screenshots;
  final List<String> points;
  final List<Extra> cards;
  final bool showTiers;

  const Chapter({
    required this.id,
    required this.name,
    required this.summary,
    required this.title,
    required this.body,
    required this.accent,
    required this.screenshots,
    this.points = const [],
    this.cards = const [],
    this.showTiers = false,
  });
}

/// The hero's playable duel (05_WEBSITE §2): pairs of highly rated titles from one ranking.
class Duel {
  /// `tv` or `movie`: a pair never mixes the two rankings.
  final String mediaType;

  /// Size of the example ranking the scores are computed for.
  final int total;
  final List<(String, String)> pairs;

  const Duel({required this.mediaType, required this.total, required this.pairs});

  /// Every title in the pairs, in order, once.
  List<String> get titles => [
        for (final (a, b) in pairs) ...[a, b],
      ].fold(<String>[], (all, t) => all.contains(t) ? all : (all..add(t)));
}

/// File-name stem for a title's generated poster (`assets/posters/<slug>.png`).
String posterSlug(String title) =>
    title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

class Extra {
  final String title;
  final String body;
  const Extra(this.title, this.body);
}

class SiteContent {
  final String name;
  final Uri url;
  final String title;
  final String description;
  final String contactEmail;
  final String copyrightHolder;
  final StoreLinks stores;
  final String heroEyebrow;
  final String heroHeadline;
  final String heroTagline;
  final String heroBody;
  final Duel duel;
  final List<Chapter> chapters;
  final List<Extra> extras;
  final String ctaTitle;
  final String ctaBody;

  const SiteContent({
    required this.name,
    required this.url,
    required this.title,
    required this.description,
    required this.contactEmail,
    required this.copyrightHolder,
    required this.stores,
    required this.heroEyebrow,
    required this.heroHeadline,
    required this.heroTagline,
    required this.heroBody,
    required this.duel,
    required this.chapters,
    required this.extras,
    required this.ctaTitle,
    required this.ctaBody,
  });

  /// Every screenshot id the page uses.
  Set<String> get screenshots => {for (final c in chapters) ...c.screenshots};

  /// Every color token name the page uses.
  Set<String> get accents => {for (final c in chapters) c.accent};

  /// Path part of [url] (`/Telly/`), used to build site-root links.
  String get basePath => url.path.endsWith('/') ? url.path : '${url.path}/';
}

SiteContent parseSiteContent(String yamlSource) {
  final root = _map(loadYaml(yamlSource), 'the document');
  final site = _map(root['site'], 'site');
  final stores = root['stores'] == null ? const <String, Object?>{} : _map(root['stores'], 'stores');
  final hero = _map(root['hero'], 'hero');
  final cta = _map(root['cta'], 'cta');

  final url = Uri.tryParse(_str(site, 'url', 'site'));
  if (url == null || !url.isAbsolute || !url.path.endsWith('/')) {
    throw SiteContentError('site.url must be an absolute URL ending in "/"');
  }
  final email = _str(site, 'contact_email', 'site');
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    throw SiteContentError('site.contact_email "$email" is not an email address');
  }

  final chapters = [
    for (final (i, raw) in _list(root['chapters'], 'chapters').indexed)
      () {
        final c = _map(raw, 'chapters[$i]');
        final where = 'chapters[$i]';
        final id = _str(c, 'id', where);
        if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(id)) throw SiteContentError('$where.id "$id" must be a lowercase anchor');
        final shots = [for (final s in _list(c['screenshots'], '$where.screenshots')) '$s'];
        if (shots.isEmpty || shots.length > 2) throw SiteContentError('$where.screenshots needs one or two scene ids');
        return Chapter(
          id: id,
          name: _str(c, 'name', where),
          summary: _str(c, 'summary', where),
          title: _str(c, 'title', where),
          body: _str(c, 'body', where),
          accent: _str(c, 'accent', where),
          screenshots: shots,
          points: [for (final p in c['points'] == null ? const [] : _list(c['points'], '$where.points')) '$p'],
          cards: [
            for (final (j, card) in (c['cards'] == null ? const [] : _list(c['cards'], '$where.cards')).indexed)
              () {
                final m = _map(card, '$where.cards[$j]');
                return Extra(_str(m, 'title', '$where.cards[$j]'), _str(m, 'body', '$where.cards[$j]'));
              }(),
          ],
          showTiers: c['show_tiers'] == true,
        );
      }(),
  ];
  if (chapters.isEmpty) throw SiteContentError('chapters needs at least one chapter');
  final ids = chapters.map((c) => c.id).toList();
  if (ids.toSet().length != ids.length) throw SiteContentError('chapter ids must be unique');

  return SiteContent(
    name: _str(site, 'name', 'site'),
    url: url,
    title: _str(site, 'title', 'site'),
    description: _str(site, 'description', 'site'),
    contactEmail: email,
    copyrightHolder: _str(site, 'copyright_holder', 'site'),
    stores: StoreLinks(
      appStore: _storeUrl(stores['app_store'], 'app_store'),
      playStore: _storeUrl(stores['play_store'], 'play_store'),
    ),
    heroEyebrow: _str(hero, 'eyebrow', 'hero'),
    heroHeadline: _str(hero, 'headline', 'hero'),
    heroTagline: _str(hero, 'tagline', 'hero'),
    heroBody: _str(hero, 'body', 'hero'),
    duel: _duel(_map(hero['duel'], 'hero.duel')),
    chapters: chapters,
    extras: [
      for (final (i, raw) in (root['extras'] == null ? const [] : _list(root['extras'], 'extras')).indexed)
        () {
          final e = _map(raw, 'extras[$i]');
          return Extra(_str(e, 'title', 'extras[$i]'), _str(e, 'body', 'extras[$i]'));
        }(),
    ],
    ctaTitle: _str(cta, 'title', 'cta'),
    ctaBody: _str(cta, 'body', 'cta'),
  );
}

/// Checks the content against what the build produced from the app.
void validateAgainstApp(SiteContent content, {required Set<String> screenshots, required Set<String> colorTokens}) {
  final missing = content.screenshots.difference(screenshots);
  if (missing.isNotEmpty) {
    throw SiteContentError(
      'no screenshot for ${missing.join(', ')}; add a Scene to tool/site/src/scenes.dart '
      '(available: ${(screenshots.toList()..sort()).join(', ')})',
    );
  }
  final unknown = content.accents.difference(colorTokens);
  if (unknown.isNotEmpty) {
    throw SiteContentError('unknown accent ${unknown.join(', ')}; use a color token from telly_colors.dart');
  }
}

Duel _duel(Map<String, Object?> d) {
  final mediaType = _str(d, 'media_type', 'hero.duel');
  if (mediaType != 'tv' && mediaType != 'movie') throw SiteContentError('hero.duel.media_type must be tv or movie');
  final total = d['total'];
  if (total is! int || total < 2) throw SiteContentError('hero.duel.total must be a whole number of 2 or more');
  final pairs = [
    for (final (i, raw) in _list(d['pairs'], 'hero.duel.pairs').indexed)
      () {
        final pair = [for (final t in _list(raw, 'hero.duel.pairs[$i]')) '$t'.trim()];
        if (pair.length != 2 || pair.any((t) => t.isEmpty) || pair[0] == pair[1]) {
          throw SiteContentError('hero.duel.pairs[$i] must be two different titles');
        }
        return (pair[0], pair[1]);
      }(),
  ];
  if (pairs.isEmpty) throw SiteContentError('hero.duel.pairs needs at least one pair');
  return Duel(mediaType: mediaType, total: total, pairs: pairs);
}

String? _storeUrl(Object? value, String key) {
  if (value == null) return null;
  final url = Uri.tryParse('$value');
  if (url == null || url.scheme != 'https') throw SiteContentError('stores.$key must be null or an https URL');
  return '$value';
}

Map<String, Object?> _map(Object? value, String where) {
  if (value is! Map) throw SiteContentError('$where must be a mapping');
  return {for (final e in value.entries) '${e.key}': e.value};
}

List<Object?> _list(Object? value, String where) {
  if (value is! List) throw SiteContentError('$where must be a list');
  return value;
}

String _str(Map<String, Object?> map, String key, String where) {
  final value = map[key];
  if (value == null || '$value'.trim().isEmpty) throw SiteContentError('$where.$key is required');
  return '$value'.trim();
}
