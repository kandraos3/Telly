import 'package:integration_test/integration_test.dart';

import 'helpers/social_friends_journeys.dart';

/// Social friends journeys end to end (epic #48, tasks #204–#208):
/// user search, follow requests, and private profile lock gates.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  socialFriendsJourneys();
}

