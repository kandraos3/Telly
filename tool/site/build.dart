// Builds the Telly website into build/site/ (WEB-03). Run from the repo root
// after `flutter test tool/site/generate_site_test.dart`, or use
// `bash tool/site/build.sh`, which runs both.
import 'dart:io';

import 'src/site_builder.dart';

void main() {
  try {
    buildSite();
    stdout.writeln('Built build/site/ (${File('build/site/build-hash.txt').readAsStringSync().trim()})');
  } on Exception catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}
