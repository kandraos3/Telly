import '../../integration_test/helpers/gamification_journeys.dart';

/// CUJ-05 on the host (#149): the same journeys as integration_test/cuj_05_gamification_test.dart,
/// so they run on every `flutter test`, not only on the emulator.
void main() => gamificationJourneys();
