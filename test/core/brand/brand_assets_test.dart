import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// FE-BRAND-01: generated app icon and splash files per style guide §7.3.

/// Reads width, height and color type from a PNG's IHDR chunk.
({int width, int height, int colorType}) _png(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), ascii.encode('PNG'), reason: '$path is not a PNG');
  final header = ByteData.sublistView(bytes, 16, 26);
  return (width: header.getUint32(0), height: header.getUint32(4), colorType: header.getUint8(9));
}

void main() {
  group('brand masters', () {
    test('masters exist at their spec sizes', () {
      for (final name in [
        'icon_1024.png',
        'icon_android_foreground.png',
        'icon_android_background.png',
        'icon_android_monochrome.png',
      ]) {
        final png = _png('assets/brand/$name');
        expect((png.width, png.height), (1024, 1024), reason: name);
      }
      final splash = _png('assets/brand/splash_logo.png');
      expect((splash.width, splash.height), (480, 480));
    });
  });

  group('Android', () {
    test('adaptive icon uses the padded layers without a second inset, plus a themed icon', () {
      final xml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      expect(xml, contains('@drawable/ic_launcher_background'));
      expect(xml, contains('@drawable/ic_launcher_monochrome'));
      expect(RegExp(r'android:inset="(\d+)%"').allMatches(xml).map((m) => m.group(1)), everyElement('0'));
    });

    test('legacy launcher icons are generated for every density', () {
      const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      sizes.forEach((density, px) {
        final png = _png('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect((png.width, png.height), (px, px), reason: density);
      });
    });

    test('Android 12+ splash shows the mark on Void Canvas', () {
      for (final dir in ['values-v31', 'values-night-v31']) {
        final styles = File('android/app/src/main/res/$dir/styles.xml').readAsStringSync();
        expect(styles, contains('<item name="android:windowSplashScreenBackground">#08090C</item>'), reason: dir);
        expect(styles, contains('<item name="android:windowSplashScreenIconBackgroundColor">#1A1D27</item>'), reason: dir);
      }
    });

    test('app label is Telly', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:label="Telly"'));
    });
  });

  group('iOS', () {
    test('App Store icon is 1024 px with no alpha channel', () {
      final png = _png('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
      expect((png.width, png.height), (1024, 1024));
      expect(png.colorType, anyOf(0, 2), reason: 'App Store rejects icons with alpha');
    });

    test('home screen name is Telly', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, matches(RegExp(r'<key>CFBundleDisplayName</key>\s*<string>Telly</string>')));
    });
  });

  group('web', () {
    test('manifest is branded Telly on Void Canvas with full icon set', () {
      final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['name'], 'Telly');
      expect(manifest['short_name'], 'Telly');
      expect(manifest['background_color'], '#08090C');
      expect(manifest['theme_color'], '#08090C');
      for (final icon in manifest['icons'] as List) {
        final src = (icon as Map<String, dynamic>)['src'] as String;
        final px = int.parse((icon['sizes'] as String).split('x').first);
        final png = _png('web/$src');
        expect((png.width, png.height), (px, px), reason: src);
      }
    });

    test('page title and favicon are set', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<title>Telly</title>'));
      expect(File('web/favicon.png').existsSync(), isTrue);
    });
  });
}
