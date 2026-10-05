import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/discovery_models.dart';

abstract interface class DiscoveryRepository {
  Future<List<NetworkBattleground>> fetchNetworkBattlegrounds({
    String mediaType = 'tv',
    int minTitles = 1,
    int limit = 10,
  });

  Future<List<FriendBingingItem>> fetchFriendsBinging({
    int limit = 20,
    int offset = 0,
  });

  Future<List<UserSearchResult>> searchUsers(String query);

  /// Personalised picks from `get_recommended_titles` (FE-EXPLORE-03); a null
  /// `mediaType` mixes both canons.
  Future<List<RecommendedTitle>> fetchRecommendedTitles({String? mediaType, int limit = 10});

  /// What the community is ranking right now, from `get_trending_titles`.
  Future<List<RecommendedTitle>> fetchTrendingTitles({String? mediaType, int limit = 10});

  List<CuratedCanonItem> getCuratedCanons();
}

class SupabaseDiscoveryRepository implements DiscoveryRepository {
  final SupabaseClient _client;

  SupabaseDiscoveryRepository(this._client);

  @override
  Future<List<NetworkBattleground>> fetchNetworkBattlegrounds({
    String mediaType = 'tv',
    int minTitles = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _client.rpc(
        'get_network_battlegrounds',
        params: {
          'p_media_type': mediaType,
          'p_min_titles': minTitles,
          'p_limit': limit,
        },
      );
      if (response is List) {
        return response
            .map((r) =>
                NetworkBattleground.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<List<FriendBingingItem>> fetchFriendsBinging({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'get_friends_binging',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (response is List) {
        return response
            .map((r) =>
                FriendBingingItem.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final response = await _client
          .from('users')
          .select('id, username, display_name, avatar_url')
          .or('username.ilike.%$q%,display_name.ilike.%$q%')
          .eq('is_deleted', false)
          .limit(10);
      return response
          .map((r) =>
              UserSearchResult.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<RecommendedTitle>> fetchRecommendedTitles({String? mediaType, int limit = 10}) =>
      _titleList('get_recommended_titles', mediaType, limit);

  @override
  Future<List<RecommendedTitle>> fetchTrendingTitles({String? mediaType, int limit = 10}) =>
      _titleList('get_trending_titles', mediaType, limit);

  Future<List<RecommendedTitle>> _titleList(String rpc, String? mediaType, int limit) async {
    try {
      final response = await _client.rpc(rpc, params: {
        'p_media_type': mediaType,
        'p_limit': limit,
      });
      if (response is List) {
        return response
            .map((r) => RecommendedTitle.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  List<CuratedCanonItem> getCuratedCanons() {
    return const [
      CuratedCanonItem(
        id: 'stuck_the_landing',
        emoji: '🎯',
        title: 'The "Stuck the Landing" Canon',
        subtitle: 'Shows with universally revered, transcendent final episodes.',
        sampleTitles: ['Breaking Bad', 'Succession', 'Six Feet Under'],
        mediaType: 'tv',
      ),
      CuratedCanonItem(
        id: 'peak_miniseries',
        emoji: '⚡',
        title: 'Peak 1-Season Miniseries',
        subtitle: 'Limited commitments with maximum cinematic execution.',
        sampleTitles: ['Chernobyl', 'Band of Brothers', "The Queen's Gambit"],
        mediaType: 'tv',
      ),
      CuratedCanonItem(
        id: 'comfort_rewatch',
        emoji: '🛋️',
        title: 'The "Comfort Rewatch" Pantheon',
        subtitle: 'Shows our community returns to over and over again.',
        sampleTitles: ['The Office', 'Parks and Rec', 'New Girl'],
        mediaType: 'tv',
      ),
      CuratedCanonItem(
        id: 'god_tier_cinema',
        emoji: '👑',
        title: 'God Tier Hall of Fame',
        subtitle: 'All-time masterpieces scoring 9.20 or higher.',
        sampleTitles: ['Parasite', 'Interstellar', 'Spirited Away'],
        mediaType: 'movie',
      ),
    ];
  }
}

class FakeDiscoveryRepository implements DiscoveryRepository {
  List<NetworkBattleground> battlegrounds;
  List<FriendBingingItem> friendsBinging;
  List<UserSearchResult> users;
  List<RecommendedTitle> recommended;
  List<RecommendedTitle> trending;

  FakeDiscoveryRepository({
    this.recommended = const [
      RecommendedTitle(
        titleId: 60059,
        mediaType: 'tv',
        title: 'Better Call Saul',
        network: 'AMC',
        communityScore: 9.48,
        reason: RecommendationReason.becauseYouLoved,
        reasonTitle: 'Breaking Bad',
      ),
      RecommendedTitle(
        titleId: 27205,
        mediaType: 'movie',
        title: 'Inception',
        communityScore: 9.55,
        reason: RecommendationReason.trending,
      ),
    ],
    this.trending = const [
      RecommendedTitle(
        titleId: 126308,
        mediaType: 'tv',
        title: 'Shogun',
        network: 'FX',
        releaseYear: 2024,
        reason: RecommendationReason.trending,
      ),
      RecommendedTitle(
        titleId: 693134,
        mediaType: 'movie',
        title: 'Dune: Part Two',
        releaseYear: 2024,
        reason: RecommendationReason.trending,
      ),
    ],
    this.battlegrounds = const [
      NetworkBattleground(
        network: 'HBO',
        titleCount: 24,
        avgScore: 8.82,
        topTitles: [
          NetworkTopTitle(id: 1, title: 'The Wire', score: 9.85),
          NetworkTopTitle(id: 2, title: 'Succession', score: 9.78),
          NetworkTopTitle(id: 3, title: 'The Sopranos', score: 9.75),
        ],
      ),
      NetworkBattleground(
        network: 'Apple TV+',
        titleCount: 16,
        avgScore: 8.41,
        topTitles: [
          NetworkTopTitle(id: 1396, title: 'Severance', score: 9.72),
          NetworkTopTitle(id: 4, title: 'Slow Horses', score: 8.94),
          NetworkTopTitle(id: 5, title: 'Ted Lasso', score: 8.65),
        ],
      ),
      NetworkBattleground(
        network: 'Netflix',
        titleCount: 38,
        avgScore: 7.64,
        topTitles: [
          NetworkTopTitle(id: 6, title: 'Mindhunter', score: 9.35),
          NetworkTopTitle(id: 7, title: 'Dark', score: 9.22),
          NetworkTopTitle(id: 8, title: 'Stranger Things', score: 8.45),
        ],
      ),
    ],
    this.friendsBinging = const [
      FriendBingingItem(
        titleId: 10,
        mediaType: 'tv',
        title: 'Shogun',
        network: 'FX / Hulu',
        communityScore: 9.31,
        activeFriendCount: 8,
        avgFriendScore: 9.31,
        friendAvatars: [
          FriendAvatarInfo(id: 'u1', username: 'jordan', displayName: 'Jordan'),
          FriendAvatarInfo(id: 'u2', username: 'maya', displayName: 'Maya'),
        ],
      ),
      FriendBingingItem(
        titleId: 4,
        mediaType: 'tv',
        title: 'Slow Horses',
        network: 'Apple TV+',
        communityScore: 8.94,
        activeFriendCount: 5,
        avgFriendScore: 8.94,
        friendAvatars: [
          FriendAvatarInfo(id: 'u2', username: 'maya', displayName: 'Maya'),
        ],
      ),
    ],
    this.users = const [
      UserSearchResult(
        id: 'u_maya',
        username: 'maya',
        displayName: 'Maya Lin',
      ),
      UserSearchResult(
        id: 'u_jordan',
        username: 'jordan',
        displayName: 'Jordan Miller',
      ),
    ],
  });

  @override
  Future<List<NetworkBattleground>> fetchNetworkBattlegrounds({
    String mediaType = 'tv',
    int minTitles = 1,
    int limit = 10,
  }) async =>
      battlegrounds;

  @override
  Future<List<FriendBingingItem>> fetchFriendsBinging({
    int limit = 20,
    int offset = 0,
  }) async =>
      friendsBinging;

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final q = query.toLowerCase();
    return users
        .where((u) =>
            u.username.toLowerCase().contains(q) ||
            u.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<RecommendedTitle>> fetchRecommendedTitles({String? mediaType, int limit = 10}) async =>
      recommended.where((t) => mediaType == null || t.mediaType == mediaType).take(limit).toList();

  @override
  Future<List<RecommendedTitle>> fetchTrendingTitles({String? mediaType, int limit = 10}) async =>
      trending.where((t) => mediaType == null || t.mediaType == mediaType).take(limit).toList();

  @override
  List<CuratedCanonItem> getCuratedCanons() {
    return const [
      CuratedCanonItem(
        id: 'stuck_the_landing',
        emoji: '🎯',
        title: 'The "Stuck the Landing" Canon',
        subtitle: 'Shows with universally revered, transcendent final episodes.',
        sampleTitles: ['Breaking Bad', 'Succession', 'Six Feet Under'],
        mediaType: 'tv',
      ),
      CuratedCanonItem(
        id: 'peak_miniseries',
        emoji: '⚡',
        title: 'Peak 1-Season Miniseries',
        subtitle: 'Limited commitments with maximum cinematic execution.',
        sampleTitles: ['Chernobyl', 'Band of Brothers', "The Queen's Gambit"],
        mediaType: 'tv',
      ),
    ];
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return SupabaseDiscoveryRepository(ref.watch(supabaseClientProvider));
});

final networkBattlegroundsProvider =
    FutureProvider.family<List<NetworkBattleground>, String>((ref, mediaType) {
  return ref
      .watch(discoveryRepositoryProvider)
      .fetchNetworkBattlegrounds(mediaType: mediaType);
});

final friendsBingingProvider = FutureProvider<List<FriendBingingItem>>((ref) {
  return ref.watch(discoveryRepositoryProvider).fetchFriendsBinging();
});


final recommendedTitlesProvider = FutureProvider<List<RecommendedTitle>>((ref) {
  return ref.watch(discoveryRepositoryProvider).fetchRecommendedTitles();
});

final trendingTitlesProvider = FutureProvider<List<RecommendedTitle>>((ref) {
  return ref.watch(discoveryRepositoryProvider).fetchTrendingTitles(limit: 8);
});

/// Recent Explore searches, newest first, kept for the app session (FE-EXPLORE-03).
class RecentSearchesController extends Notifier<List<String>> {
  static const maxEntries = 6;

  @override
  List<String> build() => const [];

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [
      q,
      ...state.where((s) => s.toLowerCase() != q.toLowerCase()),
    ].take(maxEntries).toList();
  }

  void remove(String query) => state = state.where((s) => s != query).toList();

  void clear() => state = const [];
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);
