import 'package:integration_test/integration_test.dart';

import 'helpers/gamification_journeys.dart';

/// CUJ-05: medals, challenges and levels end to end (#149, epic #50).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  gamificationJourneys();
}
