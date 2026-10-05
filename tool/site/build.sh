#!/usr/bin/env bash
# Builds the Telly website into build/site/ (WEB-04), exactly as CI does:
#   bash tool/site/build.sh            # build
#   bash tool/site/build.sh --serve    # build, then preview on http://localhost:8000
set -euo pipefail
cd "$(dirname "$0")/../.."

# Emoji for screenshots (flutter test can't use system fonts). Twemoji, CC BY 4.0.
EMOJI=build/site_cache/TwemojiMozilla.ttf
if [ ! -s "$EMOJI" ]; then
  mkdir -p "$(dirname "$EMOJI")"
  curl -fsSL -o "$EMOJI" https://github.com/mozilla/twemoji-colr/releases/download/v0.7.0/Twemoji.Mozilla.ttf
fi

rm -rf build/site_gen
flutter test tool/site/generate_site_test.dart
dart run tool/site/build.dart

if [ "${1:-}" = "--serve" ]; then
  echo "Serving build/site on http://localhost:8000"
  (cd build/site && python3 -m http.server 8000 2>/dev/null || python -m http.server 8000)
fi
