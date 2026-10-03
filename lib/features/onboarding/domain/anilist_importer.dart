import 'package:dio/dio.dart';
import '../../ranking/domain/sentiment_bracket.dart';

class AniListUserNotFoundException implements Exception {
  final String username;
  const AniListUserNotFoundException(this.username);

  @override
  String toString() => 'AniList profile not found for @$username';
}

class AniListSyncException implements Exception {
  final String message;
  const AniListSyncException(this.message);

  @override
  String toString() => message;
}

class AniListEntry {
  final int id;
  final int? idMal;
  final String romajiTitle;
  final String? englishTitle;
  final String? nativeTitle;
  final String format;
  final int? episodes;
  final String? studio;
  final String? coverImageUrl;
  final double? userScore; // 1.0 - 10.0
  final List<String> genres;
  final String? source;

  const AniListEntry({
    required this.id,
    this.idMal,
    required this.romajiTitle,
    this.englishTitle,
    this.nativeTitle,
    required this.format,
    this.episodes,
    this.studio,
    this.coverImageUrl,
    this.userScore,
    this.genres = const [],
    this.source,
  });

  String get preferredTitle =>
      (englishTitle != null && englishTitle!.trim().isNotEmpty)
          ? englishTitle!
          : romajiTitle;

  SentimentBracket get sentimentBracket {
    if (userScore == null || userScore! <= 0) {
      return SentimentBracket.liked;
    }
    return SentimentBracketExtension.fromScore(userScore!);
  }

  factory AniListEntry.fromJson(Map<String, dynamic> json) {
    final media = json['media'] as Map<String, dynamic>? ?? {};
    final title = media['title'] as Map<String, dynamic>? ?? {};
    final studiosObj = media['studios'] as Map<String, dynamic>?;
    final studioNodes = studiosObj?['nodes'] as List<dynamic>?;
    final studioName = (studioNodes != null && studioNodes.isNotEmpty)
        ? studioNodes.first['name'] as String?
        : null;

    final coverImage = media['coverImage'] as Map<String, dynamic>?;
    final coverUrl = coverImage?['extraLarge'] as String? ?? coverImage?['large'] as String?;

    final rawScore = json['score'];
    double? parsedScore;
    if (rawScore is num) {
      parsedScore = rawScore.toDouble();
      // If scored on 100-point scale, normalize to 10-point scale
      if (parsedScore > 10.0) {
        parsedScore = parsedScore / 10.0;
      }
    }

    final rawGenres = media['genres'] as List<dynamic>?;
    final parsedGenres = rawGenres?.map((g) => g.toString()).toList() ?? <String>[];

    return AniListEntry(
      id: media['id'] as int? ?? 0,
      idMal: media['idMal'] as int?,
      romajiTitle: title['romaji'] as String? ?? 'Untitled Anime',
      englishTitle: title['english'] as String?,
      nativeTitle: title['native'] as String?,
      format: media['format'] as String? ?? 'TV',
      episodes: media['episodes'] as int?,
      studio: studioName,
      coverImageUrl: coverUrl,
      userScore: parsedScore,
      genres: parsedGenres,
      source: media['source'] as String?,
    );
  }
}

class AniListImporter {
  static const String anilistEndpoint = 'https://graphql.anilist.co';

  final Dio _dio;

  AniListImporter({Dio? dio}) : _dio = dio ?? Dio();

  static const String queryCompletedAnime = '''
query GetUserCompletedAnime(\$username: String) {
  MediaListCollection(userName: \$username, type: ANIME, status: COMPLETED) {
    lists {
      name
      entries {
        score(format: POINT_10_DECIMAL)
        media {
          id
          idMal
          title {
            romaji
            english
            native
          }
          format
          episodes
          studios(isMain: true) {
            nodes {
              name
            }
          }
          coverImage {
            large
            extraLarge
          }
          genres
          source
        }
      }
    }
  }
}
''';

  /// Parses the raw GraphQL response data into a list of [AniListEntry].
  static List<AniListEntry> parseJson(Map<String, dynamic> data) {
    final mediaListCollection = data['MediaListCollection'] as Map<String, dynamic>?;
    if (mediaListCollection == null) return [];

    final lists = mediaListCollection['lists'] as List<dynamic>?;
    if (lists == null) return [];

    final result = <AniListEntry>[];
    final seenIds = <int>{};

    for (final list in lists) {
      if (list is! Map<String, dynamic>) continue;
      final entries = list['entries'] as List<dynamic>?;
      if (entries == null) continue;

      for (final entryJson in entries) {
        if (entryJson is! Map<String, dynamic>) continue;
        final entry = AniListEntry.fromJson(entryJson);
        if (entry.id != 0 && seenIds.add(entry.id)) {
          result.add(entry);
        }
      }
    }

    return result;
  }

  /// Roll up multiple seasons / cours of the same franchise into unified parent representations.
  /// E.g. "Attack on Titan Season 1", "Attack on Titan Season 2", "Attack on Titan: The Final Season"
  /// become a single franchise entry.
  static List<AniListEntry> rollupFranchises(List<AniListEntry> entries) {
    final Map<String, List<AniListEntry>> franchiseBuckets = {};

    for (final entry in entries) {
      final key = _extractFranchiseKey(entry.preferredTitle);
      franchiseBuckets.putIfAbsent(key, () => []).add(entry);
    }

    final rolledUp = <AniListEntry>[];

    for (final bucket in franchiseBuckets.values) {
      if (bucket.length == 1) {
        rolledUp.add(bucket.first);
      } else {
        // Consolidate franchise: Pick top score and sum episodes
        final primary = bucket.first;
        double? maxScore;
        int totalEpisodes = 0;

        for (final item in bucket) {
          if (item.userScore != null) {
            if (maxScore == null || item.userScore! > maxScore) {
              maxScore = item.userScore;
            }
          }
          totalEpisodes += (item.episodes ?? 0);
        }

        rolledUp.add(
          AniListEntry(
            id: primary.id,
            idMal: primary.idMal,
            romajiTitle: _extractFranchiseDisplayName(primary.romajiTitle),
            englishTitle: primary.englishTitle != null
                ? _extractFranchiseDisplayName(primary.englishTitle!)
                : null,
            nativeTitle: primary.nativeTitle,
            format: 'FRANCHISE',
            episodes: totalEpisodes > 0 ? totalEpisodes : primary.episodes,
            studio: primary.studio,
            coverImageUrl: primary.coverImageUrl,
            userScore: maxScore ?? primary.userScore,
            genres: primary.genres,
            source: primary.source,
          ),
        );
      }
    }

    return rolledUp;
  }

  static String _extractFranchiseKey(String title) {
    var clean = title.toLowerCase().trim();
    // Strip common season and cour suffixes
    clean = clean.replaceAll(RegExp(r'(:?\s+season\s+\d+.*)|(:?\s+part\s+\d+.*)|(:?\s+cour\s+\d+.*)|(:?\s+the\s+final\s+season.*)|(:?\s+2nd\s+season.*)|(:?\s+3rd\s+season.*)'), '');
    return clean.trim();
  }

  static String _extractFranchiseDisplayName(String title) {
    var clean = title.trim();
    clean = clean.replaceAll(RegExp(r'(:?\s+Season\s+\d+.*)|(:?\s+Part\s+\d+.*)|(:?\s+Cour\s+\d+.*)|(:?\s+The\s+Final\s+Season.*)|(:?\s+2nd\s+Season.*)|(:?\s+3rd\s+Season.*)', caseSensitive: false), '');
    return clean.trim();
  }

  /// Fetches the user's completed anime list from the public AniList GraphQL endpoint.
  Future<List<AniListEntry>> fetchUserAnime(
    String username, {
    bool enableFranchiseRollup = false,
  }) async {
    final cleanUsername = username.trim().replaceAll('@', '');
    if (cleanUsername.isEmpty) {
      throw const AniListSyncException('Please provide a valid AniList username.');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        anilistEndpoint,
        data: {
          'query': queryCompletedAnime,
          'variables': {'username': cleanUsername},
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final body = response.data;
      if (body == null) {
        throw const AniListSyncException('Empty response received from AniList.');
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List<dynamic>;
        final errorMsg = errors.isNotEmpty ? errors.first['message']?.toString() : 'Unknown error';
        if (errorMsg != null && errorMsg.toLowerCase().contains('not found')) {
          throw AniListUserNotFoundException(cleanUsername);
        }
        throw AniListSyncException('AniList Error: $errorMsg');
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const AniListSyncException('Malformed GraphQL data received.');
      }

      final entries = parseJson(data);
      if (enableFranchiseRollup) {
        return rollupFranchises(entries);
      }
      return entries;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw AniListUserNotFoundException(cleanUsername);
      }
      throw AniListSyncException('Network error communicating with AniList: ${e.message}');
    }
  }
}
