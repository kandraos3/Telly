// Renders the brand PNG masters in assets/brand/ from TellyLogoPainter (FE-BRAND-01).
// Not part of `flutter test`; run on demand, then regenerate the platform files:
//   flutter test tool/brand/generate_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
// Spec: docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md §7.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_logo.dart';

/// Android adaptive layers are 108 dp, of which the launcher shows the central 72 dp.
const double adaptiveInset = (108 - 72) / 2 / 108;

Future<void> _render(String name, int px, TellyLogoPainter painter, {double cornerRadius = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size.square(px.toDouble());
  if (cornerRadius > 0) {
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(px * cornerRadius)));
  }
  painter.paint(canvas, size);
  final image = await recorder.endRecording().toImage(px, px);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/brand/$name')..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    await tester.runAsync(() async {
      final font = File('assets/fonts/PlusJakartaSans-ExtraBold.ttf').readAsBytesSync();
      await (FontLoader(TellyBrand.fontFamily)..addFont(Future.value(ByteData.sublistView(font)))).load();

      await _render('icon_1024.png', 1024, const TellyLogoPainter());
      await _render('icon_android_foreground.png', 1024, const TellyLogoPainter(paintTile: false, inset: adaptiveInset));
      await _render('icon_android_background.png', 1024, const TellyLogoPainter(paintWordmark: false, inset: adaptiveInset));
      await _render(
        'icon_android_monochrome.png',
        1024,
        const TellyLogoPainter(paintTile: false, wordmarkColor: Colors.white, inset: adaptiveInset),
      );
      await _render('splash_logo.png', 480, const TellyLogoPainter(), cornerRadius: TellyBrand.cornerRadius);
    });
  });
}
