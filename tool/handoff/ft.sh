#!/bin/bash
# flutter test wrapper: Windows keeps marking build/unit_test_assets read-only.
cd /c/Users/karla/Desktop/SeriesBeli
if [ -d build/unit_test_assets ]; then
  powershell.exe -NoProfile -Command "attrib -R 'build\unit_test_assets\*' /S /D; attrib -R 'build\unit_test_assets'" >/dev/null 2>&1
  rm -rf build/unit_test_assets
fi
flutter test "$@"
