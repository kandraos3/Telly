import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/logging/presentation/controllers/logging_session_controller.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  late ProviderContainer container;
  LoggingSessionController session() => container.read(loggingSessionProvider.notifier);
  LoggingDraft draft() => container.read(loggingSessionProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(loggingSessionProvider, (_, __) {});
  });

  const bear = TitleSearchResult(id: 136315, title: 'The Bear', mediaType: 'tv', releaseYear: '2022');

  group('FE-LOG-02: LoggingSessionController rating & broadcast', () {
    test('star ratings snap to half stars within 0.5–5.0 and derive the bracket', () {
      session().selectTitle(bear);
      for (final (input, stars, bracket) in [
        (4.4, 4.5, SentimentBracket.masterpiece),
        (4.0, 4.0, SentimentBracket.loved),
        (3.2, 3.0, SentimentBracket.liked),
        (2.5, 2.5, SentimentBracket.meh),
        (0.0, 0.5, SentimentBracket.regret),
        (9.0, 5.0, SentimentBracket.masterpiece),
      ]) {
        session().setStarRating(input);
        expect(draft().starRating, stars, reason: '$input');
        expect(draft().bracket, bracket, reason: '$input');
      }
      expect(draft().canBeginDuels, isTrue);
    });

    test('broadcast defaults on, survives a title change and reaches the duel request', () {
      expect(draft().broadcast, isTrue);
      session()
        ..selectTitle(bear)
        ..setBroadcast(false)
        ..clearTitle()
        ..selectTitle(bear)
        ..setStarRating(3);
      expect(draft().broadcast, isFalse);
      expect(draft().duelRequest!.broadcast, isFalse);
    });
  });
}
