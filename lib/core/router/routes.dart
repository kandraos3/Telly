/// Route paths for every screen in `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`.
abstract final class Routes {
  static const splash = '/splash';
  static const auth = '/auth'; // SCR-01
  static const resetPassword = '/reset-password'; // opened by a password recovery link

  // Onboarding (SCR-02 … SCR-04, preceded by handle reservation)
  static const onboarding = '/onboarding';
  static const handle = '/onboarding/handle';
  static const streamingSetup = '/onboarding/streaming'; // SCR-02
  static const seedGrid = '/onboarding/seeds'; // SCR-03
  static const tournament = '/onboarding/tournament'; // SCR-04

  // Shell tabs (component spec §2.1)
  static const feed = '/feed'; // SCR-05
  static const explore = '/explore'; // SCR-07
  static const queue = '/queue'; // SCR-13
  static const canon = '/canon'; // SCR-14

  // Logging flow (full-screen, outside the shell)
  static const log = '/log'; // SCR-09
  static const duel = '/log/duel'; // SCR-10 (+ SCR-11 sheet)
  static const reveal = '/log/reveal'; // SCR-12

  // Pushed screens
  static String activity(String id) => '/feed/activity/$id'; // SCR-06
  static String title(String mediaType, int id) => '/title/$mediaType/$id'; // SCR-08
  static String profile(String handle) => '/u/$handle'; // SCR-15
  static String twoToWatch(String handle) => '/u/$handle/two-to-watch'; // SCR-16
  static const cowatch = '/cowatch'; // SCR-16
  static String cowatchWithTitle(int titleId, {String? mediaType, String? friendHandle}) =>
      '/cowatch?titleId=$titleId${mediaType != null ? '&mediaType=$mediaType' : ''}'
      '${friendHandle != null ? '&friend=$friendHandle' : ''}';
  static const squads = '/squads'; // SCR-17 list
  static String squad(String id) => '/squads/$id'; // SCR-17
  static const graveyard = '/canon/graveyard'; // SCR-18
  static const wrapped = '/canon/wrapped'; // SCR-19
  static const settings = '/canon/settings'; // SCR-20
  static const editProfile = '/canon/edit';
}
