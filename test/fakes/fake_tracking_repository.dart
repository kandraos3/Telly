import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';

/// Tracks nothing and never touches a database or the network. For screens that only need the
/// tracking provider to exist. Use the real repository over an in-memory database to test tracking.
class FakeTrackingRepository implements TrackingRepository {
  @override
  Stream<List<TrackingItem>> watchAll() => Stream.value(const []);

  @override
  Future<void> hydrate() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
