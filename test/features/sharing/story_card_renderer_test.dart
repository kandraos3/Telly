import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/sharing/presentation/widgets/story_card_renderer.dart';

void main() {
  group('FE-501: StoryCardRenderer 1080x1920 Graphic Generator Tests', () {
    test('generates valid PNG byte stream with RFC 2083 signature and 1080x1920 dimensions', () {
      final bytes = StoryCardRenderer.generateSyntheticStoryPng();

      expect(bytes.length, greaterThan(30));

      // Verify PNG signature: 89 50 4E 47 0D 0A 1A 0A
      expect(bytes.sublist(0, 8), equals(StoryCardRenderer.pngSignature));

      // Verify IHDR Chunk header
      // Offset 8: length (4 bytes), Offset 12: 'IHDR' (4 bytes), Offset 16: Width (4 bytes), Offset 20: Height (4 bytes)
      final byteData = ByteData.sublistView(bytes);
      final width = byteData.getUint32(16);
      final height = byteData.getUint32(20);

      expect(width, 1080);
      expect(height, 1920);
    });
  });
}

