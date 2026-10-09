import 'package:flutter_test/flutter_test.dart';

import '../../tool/site/src/poster_art.dart';
import '../../tool/site/src/scenes.dart';

void main() {
  group('WEB-02: site screenshot scenes', () {
    test('scene ids are unique, URL-safe file names', () {
      final ids = siteScenes.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9-]+$')));
      }
    });

    test('tab scenes use one of the four shell tabs', () {
      for (final scene in siteScenes.where((s) => s.tab != null)) {
        expect(scene.tab, inInclusiveRange(0, 3), reason: scene.id);
      }
    });

    test('#261: the scenes the chapters need exist', () {
      expect(siteScenes.map((s) => s.id), containsAll(['home', 'watching', 'achievements', 'level']));
    });

    test('backdrop paths draw the same art without the title', () {
      final url = 'https://image.tmdb.org/t/p/w780${backdropPathFor('Severance')}';
      expect(posterArtFor(url), const GeneratedPosterImage('Severance', showTitle: false));
      expect(posterArtFor(url), isNot(const GeneratedPosterImage('Severance')));
    });

    test('poster art paths round-trip the title through the poster URL', () {
      final url = 'https://image.tmdb.org/t/p/w342${posterPathFor('Dune: Part Two')}';
      expect(posterArtFor(url), const GeneratedPosterImage('Dune: Part Two'));
    });
  });
}
