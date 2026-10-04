import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  group('Sentiment Bracket Invariants (SCR-09 / QA-201)', () {
    test('displayName covers all sentiment brackets', () {
      expect(SentimentBracket.masterpiece.displayName, contains('Masterpiece'));
      expect(SentimentBracket.loved.displayName, contains('Loved'));
      expect(SentimentBracket.liked.displayName, contains('Liked'));
      expect(SentimentBracket.meh.displayName, contains('Meh'));
      expect(SentimentBracket.regret.displayName, contains('Regret'));
    });

    test('studioBrackets contains the 4 user-selectable brackets', () {
      expect(SentimentBracketExtension.studioBrackets, [
        SentimentBracket.masterpiece,
        SentimentBracket.loved,
        SentimentBracket.liked,
        SentimentBracket.meh,
      ]);
    });

    test('studioTitle and studioTagline map properly', () {
      for (final bracket in SentimentBracket.values) {
        expect(bracket.studioTitle, isNotEmpty);
        expect(bracket.studioTagline, isNotEmpty);
      }
    });

    test('fromScore maps 10-point scales accurately', () {
      expect(SentimentBracketExtension.fromScore(9.5), SentimentBracket.masterpiece);
      expect(SentimentBracketExtension.fromScore(9.0), SentimentBracket.masterpiece);
      expect(SentimentBracketExtension.fromScore(8.5), SentimentBracket.loved);
      expect(SentimentBracketExtension.fromScore(8.0), SentimentBracket.loved);
      expect(SentimentBracketExtension.fromScore(7.0), SentimentBracket.liked);
      expect(SentimentBracketExtension.fromScore(6.5), SentimentBracket.liked);
      expect(SentimentBracketExtension.fromScore(5.0), SentimentBracket.meh);
      expect(SentimentBracketExtension.fromScore(4.5), SentimentBracket.meh);
      expect(SentimentBracketExtension.fromScore(4.0), SentimentBracket.regret);
      expect(SentimentBracketExtension.fromScore(1.0), SentimentBracket.regret);
    });

    test('fromStarRating maps 5-star scales accurately', () {
      expect(SentimentBracketExtension.fromStarRating(5.0), SentimentBracket.masterpiece);
      expect(SentimentBracketExtension.fromStarRating(4.5), SentimentBracket.masterpiece);
      expect(SentimentBracketExtension.fromStarRating(4.0), SentimentBracket.loved);
      expect(SentimentBracketExtension.fromStarRating(3.5), SentimentBracket.liked);
      expect(SentimentBracketExtension.fromStarRating(3.0), SentimentBracket.liked);
      expect(SentimentBracketExtension.fromStarRating(2.5), SentimentBracket.meh);
      expect(SentimentBracketExtension.fromStarRating(2.0), SentimentBracket.meh);
      expect(SentimentBracketExtension.fromStarRating(1.5), SentimentBracket.regret);
      expect(SentimentBracketExtension.fromStarRating(0.5), SentimentBracket.regret);
    });
  });
}
