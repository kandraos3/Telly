import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/widgets/telly_logo.dart';

// FE-BRAND-01: brand mark per style guide §7.1.
void main() {
  group('TellyLogo', () {
    testWidgets('is a square tile labelled "Telly" for screen readers', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Center(child: TellyLogo(size: 96))));

      expect(tester.getSize(find.byType(TellyLogo)), const Size.square(96));
      expect(find.bySemanticsLabel('Telly'), findsOneWidget);
    });

    testWidgets('rounds its corners by the spec radius', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Center(child: TellyLogo(size: 100))));

      final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(TellyLogo), matching: find.byType(ClipRRect)));
      expect(clip.borderRadius, BorderRadius.circular(100 * TellyBrand.cornerRadius));
    });
  });

  group('TellyWordmark', () {
    testWidgets('renders lowercase lime "telly" in Jakarta ExtraBold at the requested size', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Center(child: TellyWordmark(fontSize: 28))));

      final text = tester.widget<Text>(find.text('telly'));
      expect(text.style!.fontFamily, TellyBrand.fontFamily);
      expect(text.style!.fontWeight, FontWeight.w800);
      expect(text.style!.color, TellyColors.phosphorLime);
      expect(text.style!.fontSize, closeTo(28, 1e-9));
      expect(text.style!.letterSpacing, closeTo(28 * TellyBrand.letterSpacing / TellyBrand.fontSize, 1e-9));
      expect(find.bySemanticsLabel('Telly'), findsOneWidget);
    });
  });

  group('TellyLogoPainter', () {
    Future<ByteData> render(TellyLogoPainter painter, int px) async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Size.square(px.toDouble()));
      final image = await recorder.endRecording().toImage(px, px);
      return (await image.toByteData())!;
    }

    Color pixel(ByteData rgba, int px, int x, int y) {
      final i = (y * px + x) * 4;
      return Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2));
    }

    testWidgets('places the lime wordmark on the gradient tile per spec', (tester) async {
      await tester.runAsync(() async {
        final font = File('assets/fonts/PlusJakartaSans-ExtraBold.ttf').readAsBytesSync();
        await (FontLoader(TellyBrand.fontFamily)..addFont(Future.value(ByteData.sublistView(font)))).load();

        const px = 1024;
        final rgba = await render(const TellyLogoPainter(), px);

        // Stem of the first "l" (x ≈ 520–560, cap to baseline 380–600 at 1024).
        expect(pixel(rgba, px, 538, 500), TellyColors.phosphorLime);
        // Gap above the wordmark, corner, and below the baseline are tile, not lime.
        expect(pixel(rgba, px, 512, 200), isNot(TellyColors.phosphorLime));
        expect(pixel(rgba, px, 4, 4).a, 1.0);
        expect(pixel(rgba, px, 538, 700), isNot(TellyColors.phosphorLime));
        // Gradient is lighter near the top-center than at the bottom corner.
        final top = pixel(rgba, px, 512, 205);
        final corner = pixel(rgba, px, 1020, 1020);
        expect(top.computeLuminance(), greaterThan(corner.computeLuminance()));
      });
    });

    testWidgets('an adaptive foreground is transparent outside the inset wordmark', (tester) async {
      await tester.runAsync(() async {
        const px = 512;
        final rgba = await render(const TellyLogoPainter(paintTile: false, inset: 1 / 6), px);
        expect(pixel(rgba, px, 10, 10).a, 0);
        expect(pixel(rgba, px, 256, 120).a, 0);
      });
    });
  });
}
