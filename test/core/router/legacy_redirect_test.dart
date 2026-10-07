import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/router/routes.dart';

void main() {
  String? moved(String location) => Routes.legacyRedirect(Uri.parse(location));

  group('#116: Routes.legacyRedirect (screen spec §0.0)', () {
    test('moves the old feed, queue and canon sub-paths', () {
      expect(moved('/feed'), Routes.social);
      expect(moved('/feed/activity/a1'), Routes.activity('a1'));
      expect(moved('/queue'), Routes.queue);
      expect(moved('/queue/list/l7'), Routes.customList('l7'));
      expect(moved('/canon/settings'), Routes.settings);
      expect(moved('/canon/edit'), Routes.editProfile);
      expect(moved('/canon/graveyard'), Routes.graveyard);
      expect(moved('/canon/wrapped'), Routes.wrapped);
    });

    test('keeps the query string', () {
      expect(moved('/feed?tab=global'), '${Routes.social}?tab=global');
    });

    test('leaves current paths and look-alikes alone', () {
      for (final path in [
        Routes.home,
        Routes.canon,
        Routes.social,
        Routes.more,
        Routes.queue,
        Routes.settings,
        Routes.title('tv', 1396),
        '/feeds',
        '/queued',
        '/canon/settingsx',
      ]) {
        expect(moved(path), isNull, reason: path);
      }
    });
  });
}
