import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/two_to_watch_engine.dart';

enum SwipeDirection { right, left }

class CoWatchSwipeEvent {
  final String userId;
  final int titleId;
  final SwipeDirection direction;

  const CoWatchSwipeEvent({
    required this.userId,
    required this.titleId,
    required this.direction,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title_id': titleId,
        'direction': direction.name,
      };

  factory CoWatchSwipeEvent.fromJson(Map<String, dynamic> json) =>
      CoWatchSwipeEvent(
        userId: json['user_id']?.toString() ?? '',
        titleId: (json['title_id'] as num?)?.toInt() ?? 0,
        direction: json['direction'] == 'right'
            ? SwipeDirection.right
            : SwipeDirection.left,
      );
}

abstract interface class CoWatchSessionClient {
  String get sessionId;
  String get currentUserId;
  Stream<int> get onMutualMatch;
  Stream<Set<String>> get onPresence;
  Future<void> join();
  Future<void> sendSwipe({required int titleId, required SwipeDirection direction});
  Future<void> leave();
  void dispose();
}

/// Fake Realtime Session client for testing two-player Quick-Swipe duel invariants.
class FakeCoWatchSessionClient implements CoWatchSessionClient {
  @override
  final String sessionId;
  @override
  final String currentUserId;

  final _matchController = StreamController<int>.broadcast();
  final _presenceController = StreamController<Set<String>>.broadcast();

  final Map<int, SwipeDirection> _localSwipes = {};
  final Map<int, SwipeDirection> _partnerSwipes = {};
  final Set<String> _presentUsers = {};

  void Function(CoWatchSwipeEvent)? _partnerListener;

  FakeCoWatchSessionClient({
    required this.sessionId,
    required this.currentUserId,
  }) {
    _presentUsers.add(currentUserId);
  }

  @override
  Stream<int> get onMutualMatch => _matchController.stream;

  @override
  Stream<Set<String>> get onPresence => _presenceController.stream;

  Map<int, SwipeDirection> get localSwipes => Map.unmodifiable(_localSwipes);
  Map<int, SwipeDirection> get partnerSwipes => Map.unmodifiable(_partnerSwipes);

  @override
  Future<void> join() async {
    _presenceController.add(Set.unmodifiable(_presentUsers));
  }

  @override
  Future<void> sendSwipe({
    required int titleId,
    required SwipeDirection direction,
  }) async {
    _localSwipes[titleId] = direction;
    _partnerListener?.call(
      CoWatchSwipeEvent(
        userId: currentUserId,
        titleId: titleId,
        direction: direction,
      ),
    );

    // Mutual match only when BOTH players swiped right
    if (direction == SwipeDirection.right &&
        _partnerSwipes[titleId] == SwipeDirection.right) {
      _matchController.add(titleId);
    }
  }

  /// Simulate receiving a swipe from partner over the channel.
  void simulatePartnerSwipe(CoWatchSwipeEvent event) {
    if (event.userId == currentUserId) return;
    _partnerSwipes[event.titleId] = event.direction;

    // Mutual match only when BOTH players swiped right
    if (event.direction == SwipeDirection.right &&
        _localSwipes[event.titleId] == SwipeDirection.right) {
      _matchController.add(event.titleId);
    }
  }

  /// Simulate partner joining / leaving presence.
  void simulatePartnerPresence(Set<String> userIds) {
    _presentUsers.clear();
    _presentUsers.addAll(userIds);
    _presenceController.add(Set.unmodifiable(_presentUsers));
  }

  /// Connect two fake session clients to simulate two physical phones over Realtime.
  static void connectPair(
    FakeCoWatchSessionClient clientA,
    FakeCoWatchSessionClient clientB,
  ) {
    clientA._partnerListener = (event) => clientB.simulatePartnerSwipe(event);
    clientB._partnerListener = (event) => clientA.simulatePartnerSwipe(event);

    final combined = {clientA.currentUserId, clientB.currentUserId};
    clientA.simulatePartnerPresence(combined);
    clientB.simulatePartnerPresence(combined);
  }

  @override
  Future<void> leave() async {
    _presentUsers.remove(currentUserId);
    _presenceController.add(Set.unmodifiable(_presentUsers));
  }

  @override
  void dispose() {
    _matchController.close();
    _presenceController.close();
  }
}

/// Supabase Realtime Session Client connecting to `cowatch:<session>` channel.
class SupabaseCoWatchSessionClient implements CoWatchSessionClient {
  @override
  final String sessionId;
  @override
  final String currentUserId;

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  final _matchController = StreamController<int>.broadcast();
  final _presenceController = StreamController<Set<String>>.broadcast();

  final Map<int, SwipeDirection> _localSwipes = {};
  final Map<int, SwipeDirection> _partnerSwipes = {};

  SupabaseCoWatchSessionClient(
    this._client, {
    required this.sessionId,
    required this.currentUserId,
  });

  @override
  Stream<int> get onMutualMatch => _matchController.stream;

  @override
  Stream<Set<String>> get onPresence => _presenceController.stream;

  @override
  Future<void> join() async {
    final channel = _client.channel('cowatch:$sessionId');
    _channel = channel;

    channel.onBroadcast(
      event: 'swipe',
      callback: (payload) {
        final event = CoWatchSwipeEvent.fromJson(payload);
        if (event.userId != currentUserId) {
          _handlePartnerSwipe(event);
        }
      },
    );

    channel.onPresenceSync((_) {
      final userIds = <String>{};
      for (final state in channel.presenceState()) {
        for (final pres in state.presences) {
          final uid = pres.payload['user_id'];
          if (uid != null) userIds.add(uid.toString());
        }
      }
      _presenceController.add(userIds);
    });

    channel.subscribe();
    await channel.track({
      'user_id': currentUserId,
      'online_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void _handlePartnerSwipe(CoWatchSwipeEvent event) {
    _partnerSwipes[event.titleId] = event.direction;
    if (event.direction == SwipeDirection.right &&
        _localSwipes[event.titleId] == SwipeDirection.right) {
      _matchController.add(event.titleId);
    }
  }

  @override
  Future<void> sendSwipe({
    required int titleId,
    required SwipeDirection direction,
  }) async {
    _localSwipes[titleId] = direction;

    final channel = _channel;
    if (channel != null) {
      await channel.sendBroadcastMessage(
        event: 'swipe',
        payload: CoWatchSwipeEvent(
          userId: currentUserId,
          titleId: titleId,
          direction: direction,
        ).toJson(),
      );
    }

    if (direction == SwipeDirection.right &&
        _partnerSwipes[titleId] == SwipeDirection.right) {
      _matchController.add(titleId);
    }
  }

  @override
  Future<void> leave() async {
    final channel = _channel;
    if (channel != null) {
      await channel.untrack();
      await channel.unsubscribe();
      _channel = null;
    }
  }

  @override
  void dispose() {
    leave();
    _matchController.close();
    _presenceController.close();
  }
}

abstract interface class CoWatchRepository {
  Future<List<CoWatchCandidate>> fetchCandidates({
    required String partnerId,
    required String mediaType,
  });

  CoWatchSessionClient createSessionClient({
    required String sessionId,
    String? currentUserId,
  });
}

class SupabaseCoWatchRepository implements CoWatchRepository {
  final SupabaseClient _client;

  SupabaseCoWatchRepository(this._client);

  @override
  Future<List<CoWatchCandidate>> fetchCandidates({
    required String partnerId,
    required String mediaType,
  }) async {
    final response = await _client.rpc(
      'get_co_watch_candidates',
      params: {
        'p_partner_id': partnerId,
        'p_media_type': mediaType,
      },
    );

    if (response is! List) return [];

    return response
        .map((row) => CoWatchCandidate.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  CoWatchSessionClient createSessionClient({
    required String sessionId,
    String? currentUserId,
  }) {
    final uid = currentUserId ?? _client.auth.currentUser?.id ?? 'anonymous';
    return SupabaseCoWatchSessionClient(
      _client,
      sessionId: sessionId,
      currentUserId: uid,
    );
  }
}

final coWatchRepositoryProvider = Provider<CoWatchRepository>((ref) {
  return SupabaseCoWatchRepository(ref.watch(supabaseClientProvider));
});
