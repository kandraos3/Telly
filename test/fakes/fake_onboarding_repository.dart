import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';

/// In-memory [OnboardingRepository] (FE-606/FE-608).
class FakeOnboardingRepository implements OnboardingRepository {
  final saves = <(Set<String>, bool)>[];
  bool fail = false;

  @override
  Future<void> saveStreamingSetup({required Set<String> platformIds, required bool includeFreePlatforms}) async {
    if (fail) throw Exception('offline');
    saves.add((platformIds, includeFreePlatforms));
  }

  @override
  Future<StreamingSetup> fetchStreamingSetup() async =>
      saves.isEmpty ? const StreamingSetup({}, includeFreePlatforms: false) : StreamingSetup(saves.last.$1, includeFreePlatforms: saves.last.$2);
}
