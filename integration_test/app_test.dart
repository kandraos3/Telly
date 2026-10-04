import 'package:integration_test/integration_test.dart';

import 'cuj_01_onboarding_test.dart' as cuj_01;
import 'cuj_02_logging_duel_test.dart' as cuj_02;
import 'cuj_03_cowatch_decider_test.dart' as cuj_03;
import 'cuj_04_offline_sync_resilience_test.dart' as cuj_04;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  cuj_01.main();
  cuj_02.main();
  cuj_03.main();
  cuj_04.main();
}
