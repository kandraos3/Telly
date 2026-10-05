import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/poster_image.dart';

void main() {
  const fallback = Text('fallback');
  final art = MemoryImage(Uint8List(0));

  Future<void> pump(WidgetTester tester, List<Override> overrides, {String? path = '/abc.jpg'}) =>
      tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: PosterImage(posterPath: path, fallback: fallback)),
      ));

  group('WEB-02: PosterImage offline poster art', () {
    testWidgets('shows the fallback when network posters are off and no art is supplied', (tester) async {
      await pump(tester, [posterNetworkImagesProvider.overrideWithValue(false)]);
      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('asks posterArtProvider for the full poster URL when network posters are off', (tester) async {
      final requested = <String>[];
      await pump(tester, [
        posterNetworkImagesProvider.overrideWithValue(false),
        posterArtProvider.overrideWithValue((url) {
          requested.add(url);
          return art;
        }),
      ]);
      expect(requested, ['https://image.tmdb.org/t/p/w342/abc.jpg']);
      expect((tester.widget<Image>(find.byType(Image)).image), same(art));
    });

    testWidgets('a title without a poster path still shows the fallback', (tester) async {
      await pump(tester, [
        posterNetworkImagesProvider.overrideWithValue(false),
        posterArtProvider.overrideWithValue((_) => art),
      ], path: null);
      expect(find.text('fallback'), findsOneWidget);
    });

    test('the app supplies no poster art', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(posterArtProvider), isNull);
    });
  });
}
