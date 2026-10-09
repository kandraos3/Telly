// Generated poster art for site screenshots (WEB-02): gradients from the app's
// tier palette with the title in the display serif, so the site never shows
// studio artwork.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:telly_app/core/theme/telly_colors.dart';

/// Fixture poster paths look like `/site/<Title>`; the art is drawn from the title.
const posterPathPrefix = '/site/';

String posterPathFor(String title) => '$posterPathPrefix${Uri.encodeComponent(title)}';

/// Backdrop paths (`/site-backdrop/<Title>`) get the same art without the title, so text laid
/// over a backdrop (Home's Tonight hero) doesn't sit on top of a second title.
const backdropPathPrefix = '/site-backdrop/';

String backdropPathFor(String title) => '$backdropPathPrefix${Uri.encodeComponent(title)}';

/// The art for a `PosterImage` URL, for `posterArtProvider`.
ImageProvider posterArtFor(String url) {
  final backdrop = url.indexOf(backdropPathPrefix);
  if (backdrop >= 0) {
    return GeneratedPosterImage(Uri.decodeComponent(url.substring(backdrop + backdropPathPrefix.length)), showTitle: false);
  }
  final index = url.indexOf(posterPathPrefix);
  final title = index < 0 ? url : Uri.decodeComponent(url.substring(index + posterPathPrefix.length));
  return GeneratedPosterImage(title);
}

const _palette = [
  (TellyColors.tierGodStart, TellyColors.tierGodEnd),
  (TellyColors.tierPrestigeStart, TellyColors.tierPrestigeEnd),
  (TellyColors.tierGreatStart, TellyColors.tierGreatEnd),
  (TellyColors.tierGoodStart, TellyColors.tierGoodEnd),
  (TellyColors.tierDroppedStart, TellyColors.tierDroppedEnd),
  (TellyColors.phosphorLime, TellyColors.electricCyan),
  (TellyColors.neonCoral, TellyColors.electricViolet),
];

@immutable
class GeneratedPosterImage extends ImageProvider<GeneratedPosterImage> {
  final String title;

  /// False for backdrops: the same art, no title.
  final bool showTitle;
  const GeneratedPosterImage(this.title, {this.showTitle = true});

  static const width = 342;
  static const height = 513;

  @override
  Future<GeneratedPosterImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(GeneratedPosterImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_render().then((image) => ImageInfo(image: image)));

  Future<ui.Image> _render() {
    // Stable across runs (String.hashCode is not).
    final seed = title.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    final random = math.Random(seed);
    final (bright, deep) = _palette[seed % _palette.length];
    const size = Size(width * 1.0, height * 1.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          Color.lerp(deep, TellyColors.backgroundPrimary, 0.35)!,
          Color.lerp(deep, TellyColors.backgroundPrimary, 0.88)!,
        ]),
    );
    final glow = Offset(size.width * (0.2 + random.nextDouble() * 0.6), size.height * (0.15 + random.nextDouble() * 0.3));
    canvas.drawCircle(
      glow,
      size.width * 0.75,
      Paint()
        ..shader = ui.Gradient.radial(glow, size.width * 0.75, [
          bright.withValues(alpha: 0.75),
          bright.withValues(alpha: 0),
        ]),
    );
    final band = Paint()..color = TellyColors.textPrimary.withValues(alpha: 0.06);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.1 + random.nextDouble() * 0.5);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2 + random.nextDouble() * 10), band);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, size.height * 0.3), Offset(0, size.height * 0.7), [
          TellyColors.backgroundPrimary.withValues(alpha: 0),
          TellyColors.backgroundPrimary.withValues(alpha: 0.55),
        ]),
    );

    if (!showTitle) return recorder.endRecording().toImage(width, height);

    final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'PlayfairDisplay_700',
      fontSize: title.length > 14 ? 40 : 50,
      height: 1.05,
      maxLines: 4,
      ellipsis: '…',
    ))
          ..pushStyle(ui.TextStyle(color: TellyColors.textPrimary, letterSpacing: -1))
          ..addText(title))
        .build()
      ..layout(ui.ParagraphConstraints(width: size.width - 44));
    // Centered: posters are cropped to many aspect ratios (BoxFit.cover).
    canvas.drawParagraph(paragraph, Offset(22, (size.height - paragraph.height) / 2));

    return recorder.endRecording().toImage(width, height);
  }

  @override
  bool operator ==(Object other) => other is GeneratedPosterImage && other.title == title && other.showTitle == showTitle;

  @override
  int get hashCode => Object.hash(title, showTitle);
}
