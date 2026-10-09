import '../../integration_test/helpers/tracking_journeys.dart';

/// CUJ-06 on the host (#233): the same journey as integration_test/cuj_06_tracking_test.dart, so it
/// runs on every `flutter test`, not only on the emulator.
void main() => trackingJourneys();
