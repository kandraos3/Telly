import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';

/// In-memory [CoWatchRepository] for SCR-16 tests (FE-COWATCH-01).
class FakeCoWatchRepository implements CoWatchRepository {
  FakeCoWatchRepository({
    this.partners = const [],
    Map<String, List<CoWatchCandidate>>? pools,
    this.streaming = SharedStreaming.unknown,
  }) : pools = pools ?? {};

  List<CoWatchPartner> partners;

  /// Candidate pools per media type, shared by every partner.
  final Map<String, List<CoWatchCandidate>> pools;
  SharedStreaming streaming;
  bool failCandidates = false;

  final candidateCalls = <(String, String)>[];

  @override
  Future<List<CoWatchCandidate>> fetchCandidates({required String partnerId, required String mediaType}) async {
    candidateCalls.add((partnerId, mediaType));
    if (failCandidates) throw Exception('offline');
    return pools[mediaType] ?? const [];
  }

  @override
  Future<List<CoWatchPartner>> fetchPartners() async => partners;

  @override
  Future<SharedStreaming> fetchSharedStreaming(String partnerId) async => streaming;

  @override
  CoWatchSessionClient createSessionClient({required String sessionId, String? currentUserId}) =>
      FakeCoWatchSessionClient(sessionId: sessionId, currentUserId: currentUserId ?? 'me');
}
