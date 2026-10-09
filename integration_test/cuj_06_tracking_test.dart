import 'package:integration_test/integration_test.dart';

import 'helpers/tracking_journeys.dart';

/// CUJ-06: track a series to its finale, end to end (#233, epic #168).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  trackingJourneys();
}
