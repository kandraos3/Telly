import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/editorial_tagging.dart';

void main() {
  group('Editorial Tagging Domain Invariants (SCR-11 / QA-203)', () {
    test('ViewingVenue parses from DB values accurately', () {
      expect(ViewingVenue.fromDbValue('HOME'), equals(ViewingVenue.home));
      expect(ViewingVenue.fromDbValue('THEATER'), equals(ViewingVenue.theatrical));
      expect(ViewingVenue.fromDbValue('IMAX'), equals(ViewingVenue.imax));
      expect(ViewingVenue.fromDbValue('OTHER'), equals(ViewingVenue.festivalFlight));
      expect(ViewingVenue.fromDbValue('UNKNOWN'), isNull);
      expect(ViewingVenue.fromDbValue(null), isNull);
    });

    test('BingeVelocity parses from DB values accurately', () {
      expect(BingeVelocity.fromDbValue('WEEKEND_BINGE'), equals(BingeVelocity.weekendBinge));
      expect(BingeVelocity.fromDbValue('WEEKLY_AIRING'), equals(BingeVelocity.weeklyAiring));
      expect(BingeVelocity.fromDbValue('SLOW_BURN'), equals(BingeVelocity.slowBurn));
      expect(BingeVelocity.fromDbValue('INVALID'), isNull);
      expect(BingeVelocity.fromDbValue(null), isNull);
    });

    test('AnimeAudioMode parses from DB values accurately', () {
      expect(AnimeAudioMode.fromDbValue('SUB'), equals(AnimeAudioMode.sub));
      expect(AnimeAudioMode.fromDbValue('DUB'), equals(AnimeAudioMode.dub));
      expect(AnimeAudioMode.fromDbValue('UNKNOWN'), isNull);
      expect(AnimeAudioMode.fromDbValue(null), isNull);
    });

    test('EditorialTaggingData copyWith works correctly', () {
      const data = EditorialTaggingData(
        viewingVenue: ViewingVenue.imax,
        bingeVelocity: BingeVelocity.weekendBinge,
        audioMode: AnimeAudioMode.sub,
        rewatchCount: 2,
        isRewatch: true,
        mvpCharacter: 'Paul Atreides',
        review: 'Cinematic masterpiece in 70mm IMAX.',
      );

      expect(data.viewingVenue, equals(ViewingVenue.imax));
      expect(data.bingeVelocity, equals(BingeVelocity.weekendBinge));
      expect(data.audioMode, equals(AnimeAudioMode.sub));
      expect(data.rewatchCount, equals(2));
      expect(data.isRewatch, isTrue);
      expect(data.mvpCharacter, equals('Paul Atreides'));
      expect(data.review, equals('Cinematic masterpiece in 70mm IMAX.'));

      final modified = data.copyWith(rewatchCount: 3, mvpCharacter: 'Chani');
      expect(modified.rewatchCount, equals(3));
      expect(modified.mvpCharacter, equals('Chani'));
      expect(modified.viewingVenue, equals(ViewingVenue.imax));
    });
  });
}

