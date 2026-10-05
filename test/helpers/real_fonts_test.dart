import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'real_fonts.dart';

/// A minimal OpenType header with a `head` and an `OS/2` table directory entry.
Uint8List _font() {
  final bytes = Uint8List(12 + 2 * 16 + 8);
  final data = ByteData.sublistView(bytes)..setUint16(4, 2);
  void record(int index, String tag, int offset) {
    final at = 12 + index * 16;
    bytes.setAll(at, tag.codeUnits);
    data.setUint32(at + 8, offset);
  }

  record(0, 'head', 44);
  record(1, 'OS/2', 44);
  data.setUint16(44 + 4, 400);
  return bytes;
}

void main() {
  group('FE-QUEUE-01 / WEB-02: real fonts in flutter test', () {
    test('withWeightClass rewrites OS/2.usWeightClass on a copy', () {
      final original = _font();
      final heavy = withWeightClass(original, 800);
      expect(ByteData.sublistView(heavy).getUint16(48), 800);
      expect(ByteData.sublistView(original).getUint16(48), 400);
    });

    test('withWeightClass rejects a font without an OS/2 table', () {
      final font = _font()..setAll(12 + 16, 'cmap'.codeUnits);
      expect(() => withWeightClass(font, 700), throwsArgumentError);
    });
  });
}
