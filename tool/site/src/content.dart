// site/content.yaml, parsed and validated (WEB-03).
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

class Feature {
  final String id;
  final String eyebrow;
  final String title;
  final String body;
  final String accent;
  final String screenshot;
  final List<String> points;
  final bool showTiers;

  const Feature({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.screenshot,
    this.points = const [],
    this.showTiers = false,
  });
}

class GalleryItem {
  final String screenshot;
  final String caption;
  const GalleryItem(this.screenshot, this.caption);
}

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
  final String heroScreenshot;
  final List<Feature> features;
  final String galleryTitle;
  final String galleryBody;
  final List<GalleryItem> gallery;
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
    required this.heroScreenshot,
    required this.features,
    required this.galleryTitle,
    required this.galleryBody,
    required this.gallery,
    required this.extras,
    required this.ctaTitle,
    required this.ctaBody,
  });

  /// Every screenshot id the page uses.
  Set<String> get screenshots => {
        heroScreenshot,
        for (final f in features) f.screenshot,
        for (final g in gallery) g.screenshot,
      };

  /// Every color token name the page uses.
  Set<String> get accents => {for (final f in features) f.accent};

  /// Path part of [url] (`/Telly/`), used to build site-root links.
  String get basePath => url.path.endsWith('/') ? url.path : '${url.path}/';
}

SiteContent parseSiteContent(String yamlSource) {
  final root = _map(loadYaml(yamlSource), 'the document');
  final site = _map(root['site'], 'site');
  final stores = root['stores'] == null ? const <String, Object?>{} : _map(root['stores'], 'stores');
  final hero = _map(root['hero'], 'hero');
  final gallery = _map(root['gallery'], 'gallery');
  final cta = _map(root['cta'], 'cta');

  final url = Uri.tryParse(_str(site, 'url', 'site'));
  if (url == null || !url.isAbsolute || !url.path.endsWith('/')) {
    throw SiteContentError('site.url must be an absolute URL ending in "/"');
  }
  final email = _str(site, 'contact_email', 'site');
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    throw SiteContentError('site.contact_email "$email" is not an email address');
  }

  final features = [
    for (final (i, raw) in _list(root['features'], 'features').indexed)
      () {
        final f = _map(raw, 'features[$i]');
        final where = 'features[$i]';
        return Feature(
          id: _str(f, 'id', where),
          eyebrow: _str(f, 'eyebrow', where),
          title: _str(f, 'title', where),
          body: _str(f, 'body', where),
          accent: _str(f, 'accent', where),
          screenshot: _str(f, 'screenshot', where),
          points: [for (final p in f['points'] == null ? const [] : _list(f['points'], '$where.points')) '$p'],
          showTiers: f['show_tiers'] == true,
        );
      }(),
  ];
  final ids = features.map((f) => f.id).toList();
  if (ids.toSet().length != ids.length) throw SiteContentError('feature ids must be unique');

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
    heroScreenshot: _str(hero, 'screenshot', 'hero'),
    features: features,
    galleryTitle: _str(gallery, 'title', 'gallery'),
    galleryBody: _str(gallery, 'body', 'gallery'),
    gallery: [
      for (final (i, raw) in _list(gallery['items'], 'gallery.items').indexed)
        () {
          final g = _map(raw, 'gallery.items[$i]');
          return GalleryItem(_str(g, 'screenshot', 'gallery.items[$i]'), _str(g, 'caption', 'gallery.items[$i]'));
        }(),
    ],
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
