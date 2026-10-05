// Generates everything the site takes from the app into build/site_gen/:
// tokens.css + fonts (WEB-01). Not part of `flutter test`; run by
// tool/site/build.sh and .github/workflows/site.yml:
//   flutter test tool/site/generate_site_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/tokens.dart';
import 'src/typography_tokens.dart';

const genDir = 'build/site_gen';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
}
