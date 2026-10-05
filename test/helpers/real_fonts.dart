// Loads real glyphs into the flutter_test engine so tests measure, and the
// website's screenshots (WEB-02) show, the app's fonts, icons and emoji.
import 'dart:io';

import 'package:flutter/services.dart';

/// Where the CI workflow (and `tool/site/build.sh`) caches the Twemoji (COLR) emoji font.
const emojiFontPath = 'build/site_cache/TwemojiMozilla.ttf';

const Map<String, int> _weightNames = {
  'Thin': 100,
  'ExtraLight': 200,
  'Light': 300,
  'Regular': 400,
  'Medium': 500,
  'SemiBold': 600,
  'Bold': 700,
  'ExtraBold': 800,
  'Black': 900,
};

/// Registers every bundled `assets/fonts/<Family>-<Weight>.ttf` under each name
/// google_fonts asks for (`PlusJakartaSans_700`, `PlayfairDisplay_regular`, …)
/// using the nearest bundled weight, plus Material Icons from the Flutter SDK.
///
/// `flutter test` runs with system font fallback off, so emoji only render if
/// they sit in a family the text style lists. google_fonts always lists the
/// bare family (`PlusJakartaSans`) as the fallback, so the bare families hold
/// only the emoji font, re-weighted so every text weight resolves to it. The
/// brand wordmark (bare `PlusJakartaSans` w800) therefore can't render; it only
/// appears on the splash, sign-in and share-card screens, which are not scenes.
Future<void> loadRealFonts() async {
  final files = <String, Map<int, File>>{};
  for (final entity in Directory('assets/fonts').listSync()) {
    final name = entity.uri.pathSegments.last;
    final match = RegExp(r'^(\w+)-(\w+)\.ttf$').firstMatch(name);
    final weight = match == null ? null : _weightNames[match.group(2)];
    if (match == null || weight == null) continue;
    (files[match.group(1)!] ??= {})[weight] = entity as File;
  }

  final emojiFile = File(emojiFontPath);
  final emoji = emojiFile.existsSync() ? emojiFile.readAsBytesSync() : null;

  for (final MapEntry(key: family, value: weights) in files.entries) {
    Uint8List nearest(int target) => weights.entries
        .reduce((a, b) => (a.key - target).abs() <= (b.key - target).abs() ? a : b)
        .value
        .readAsBytesSync();
    for (var w = 100; w <= 900; w += 100) {
      await _register('${family}_${w == 400 ? 'regular' : w}', [nearest(w)]);
      await _register('${family}_${w == 400 ? '' : w}italic', [nearest(w)]);
    }
    await _register(family, [
      if (emoji == null) nearest(400) else for (var w = 100; w <= 900; w += 100) withWeightClass(emoji, w),
    ]);
    if (family == 'PlusJakartaSans') await _register('Roboto', [nearest(400)]);
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromPath();
  await _register('MaterialIcons', [
    File('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytesSync(),
  ]);
}

Future<void> _register(String family, List<Uint8List> fonts) async {
  final loader = FontLoader(family);
  for (final bytes in fonts) {
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// A copy of an OpenType font whose `OS/2.usWeightClass` reads [weight].
Uint8List withWeightClass(Uint8List font, int weight) {
  final copy = Uint8List.fromList(font);
  final data = ByteData.sublistView(copy);
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    if (String.fromCharCodes(copy, record, record + 4) == 'OS/2') {
      data.setUint16(data.getUint32(record + 8) + 4, weight);
      return copy;
    }
  }
  throw ArgumentError('font has no OS/2 table');
}

String _flutterRootFromPath() {
  // `flutter test` runs the Dart VM from <root>/bin/cache/dart-sdk/bin.
  final exe = File(Platform.resolvedExecutable).absolute.path.replaceAll(r'\', '/');
  final index = exe.indexOf('/bin/cache/');
  if (index < 0) throw StateError('Set FLUTTER_ROOT to locate Material Icons');
  return exe.substring(0, index);
}
