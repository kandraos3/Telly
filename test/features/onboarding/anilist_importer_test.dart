import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/onboarding/domain/anilist_importer.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  group('AniList GraphQL Ingestion & Deserializer Unit Tests (FE-110, QA-102)', () {
    const mockGraphQLResponse = {
      'MediaListCollection': {
        'lists': [
          {
            'name': 'Completed',
            'entries': [
              {
                'score': 9.8,
                'media': {
                  'id': 1429,
                  'idMal': 16498,
                  'title': {
                    'romaji': 'Shingeki no Kyojin',
                    'english': 'Attack on Titan Season 1',
                    'native': '進撃の巨人',
                  },
                  'format': 'TV',
                  'episodes': 25,
                  'studios': {
                    'nodes': [
                      {'name': 'Wit Studio'}
                    ]
                  },
                  'coverImage': {
                    'large': 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1429-79.jpg',
                    'extraLarge': 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/extralarge/bx1429-79.jpg'
                  },
                  'genres': ['Action', 'Drama', 'Fantasy'],
                  'source': 'MANGA'
                }
              },
              {
                'score': 9.5,
                'media': {
                  'id': 20958,
                  'idMal': 25777,
                  'title': {
                    'romaji': 'Shingeki no Kyojin Season 2',
                    'english': 'Attack on Titan Season 2',
                    'native': '進撃の巨人 Season 2',
                  },
                  'format': 'TV',
                  'episodes': 12,
                  'studios': {
                    'nodes': [
                      {'name': 'Wit Studio'}
                    ]
                  },
                  'coverImage': {
                    'large': 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20958.jpg',
                  },
                  'genres': ['Action', 'Drama', 'Fantasy'],
                  'source': 'MANGA'
                }
              },
              {
                'score': 8.8,
                'media': {
                  'id': 209867,
                  'idMal': 52991,
                  'title': {
                    'romaji': 'Sousou no Frieren',
                    'english': "Frieren: Beyond Journey's End",
                    'native': '葬送のフリーレン',
                  },
                  'format': 'TV',
                  'episodes': 28,
                  'studios': {
                    'nodes': [
                      {'name': 'Madhouse'}
                    ]
                  },
                  'coverImage': {
                    'extraLarge': 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/extralarge/bx209867.jpg'
                  },
                  'genres': ['Adventure', 'Drama', 'Fantasy'],
                  'source': 'MANGA'
                }
              },
              {
                'score': 7.2,
                'media': {
                  'id': 1535,
                  'idMal': 1535,
                  'title': {
                    'romaji': 'Death Note',
                    'english': 'Death Note',
                    'native': 'DEATH NOTE',
                  },
                  'format': 'TV',
                  'episodes': 37,
                  'studios': {
                    'nodes': [
                      {'name': 'Madhouse'}
                    ]
                  },
                  'genres': ['Mystery', 'Psychological', 'Supernatural'],
                  'source': 'MANGA'
                }
              },
              {
                'score': 5.0,
                'media': {
                  'id': 99999,
                  'title': {
                    'romaji': 'Mid Anime Show',
                  },
                  'format': 'TV',
                  'episodes': 12,
                  'genres': ['Comedy'],
                }
              },
              {
                'score': 2.5,
                'media': {
                  'id': 88888,
                  'title': {
                    'romaji': 'Terrible Adaptation',
                  },
                  'format': 'TV',
                  'episodes': 12,
                  'genres': ['Horror'],
                }
              },
            ]
          }
        ]
      }
    };

    test('parses full GraphQL JSON response into AniListEntry models', () {
      final entries = AniListImporter.parseJson(mockGraphQLResponse);

      expect(entries, hasLength(6));

      final aot = entries.first;
      expect(aot.id, equals(1429));
      expect(aot.idMal, equals(16498));
      expect(aot.preferredTitle, equals('Attack on Titan Season 1'));
      expect(aot.studio, equals('Wit Studio'));
      expect(aot.episodes, equals(25));
      expect(aot.genres, containsAll(['Action', 'Drama', 'Fantasy']));
      expect(aot.coverImageUrl, contains('bx1429-79.jpg'));
    });

    test('correctly maps scores to sentiment brackets', () {
      final entries = AniListImporter.parseJson(mockGraphQLResponse);

      // 9.8 -> masterpiece
      expect(entries[0].sentimentBracket, equals(SentimentBracket.masterpiece));
      // 9.5 -> masterpiece
      expect(entries[1].sentimentBracket, equals(SentimentBracket.masterpiece));
      // 8.8 -> loved
      expect(entries[2].sentimentBracket, equals(SentimentBracket.loved));
      // 7.2 -> liked
      expect(entries[3].sentimentBracket, equals(SentimentBracket.liked));
      // 5.0 -> meh
      expect(entries[4].sentimentBracket, equals(SentimentBracket.meh));
      // 2.5 -> regret
      expect(entries[5].sentimentBracket, equals(SentimentBracket.regret));
    });

    test('normalizes 100-point scale scores to 10-point scale', () {
      final entry = AniListEntry.fromJson({
        'score': 95,
        'media': {
          'id': 1001,
          'title': {'romaji': 'Big Score Anime'},
        }
      });

      expect(entry.userScore, equals(9.5));
      expect(entry.sentimentBracket, equals(SentimentBracket.masterpiece));
    });

    test('Franchise Rollup engine aggregates multi-season cours into single parent entity', () {
      final entries = AniListImporter.parseJson(mockGraphQLResponse);
      final rolledUp = AniListImporter.rollupFranchises(entries);

      // AOT Season 1 and Season 2 combined into one franchise entry
      final aotFranchise = rolledUp.firstWhere((e) => e.preferredTitle.contains('Attack on Titan'));
      expect(aotFranchise.preferredTitle, equals('Attack on Titan'));
      expect(aotFranchise.format, equals('FRANCHISE'));
      // Total episodes: 25 + 12 = 37
      expect(aotFranchise.episodes, equals(37));
      // Top score preserved: max(9.8, 9.5) = 9.8
      expect(aotFranchise.userScore, equals(9.8));

      // Frieren was already single: unchanged
      final frieren = rolledUp.firstWhere((e) => e.preferredTitle.contains('Frieren'));
      expect(frieren.episodes, equals(28));
    });

    test('handles empty or null GraphQL payloads gracefully', () {
      expect(AniListImporter.parseJson({}), isEmpty);
      expect(AniListImporter.parseJson({'MediaListCollection': null}), isEmpty);
      expect(AniListImporter.parseJson({'MediaListCollection': {'lists': []}}), isEmpty);
    });

    test('throws validation exception on empty username', () async {
      final importer = AniListImporter();
      expect(
        () => importer.fetchUserAnime('   '),
        throwsA(isA<AniListSyncException>()),
      );
    });
  });
}
