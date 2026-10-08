import '../../integration_test/helpers/explore_journeys.dart';

/// Explore rows on the host (#183): the same journeys as integration_test/explore_rows_test.dart,
/// so they run on every `flutter test`, not only on the emulator.
void main() => exploreJourneys();
