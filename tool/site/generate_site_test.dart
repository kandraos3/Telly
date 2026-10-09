// Generates everything the site takes from the app into build/site_gen/:
// tokens.css + fonts (WEB-01) and app screenshots (WEB-02). Not part of `flutter test`; run by
// tool/site/build.sh and .github/workflows/site.yml:
//   flutter test tool/site/generate_site_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/content.dart';
import 'src/poster_art.dart';
import 'src/scene_harness.dart';
import 'src/scenes.dart';
import '../../test/helpers/real_fonts.dart';
import 'src/tokens.dart';
import 'src/typography_tokens.dart';

const genDir = 'build/site_gen';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadRealFonts();
  });

  test('tokens.css and fonts from lib/core/theme and assets/fonts', () {
    final fonts = <FontFace>[];
    final fontOut = Directory('$genDir/fonts')..createSync(recursive: true);
    for (final file in Directory('assets/fonts').listSync().whereType<File>()) {
      final face = parseFontFile(file.uri.pathSegments.last);
      if (face == null) continue;
      fonts.add(face);
      file.copySync('${fontOut.path}/${face.fileName}');
    }
    fonts.sort((a, b) => '${a.family}${a.weight}'.compareTo('${b.family}${b.weight}'));

    final css = buildTokensCss(
      colors: parseColorTokens(File('lib/core/theme/telly_colors.dart').readAsStringSync()),
      type: tellyTypeTokens(),
      fonts: fonts,
    );
    File('$genDir/tokens.css').writeAsStringSync(css);
  });

  // #263: generated poster art for the hero duel's titles.
  testWidgets('duel posters', (tester) async {
    final content = parseSiteContent(File('site/content.yaml').readAsStringSync());
    await tester.runAsync(() async {
      for (final title in content.duel.titles) {
        final image = await GeneratedPosterImage(title, showTitle: false).render();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$genDir/posters/${posterSlug(title)}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });

  // WEB-02: one PNG per scene in build/site_gen/screenshots/.
  for (final scene in siteScenes) {
    testWidgets('screenshot: ${scene.id}', (tester) => shootScene(tester, scene, '$genDir/screenshots'));
  }
}
