import 'package:integration_test/integration_test.dart';

import 'helpers/explore_journeys.dart';

/// Explore rows end to end (#183, epic #46): Series, See all, a title and back; Not for me and Undo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  exploreJourneys();
}
