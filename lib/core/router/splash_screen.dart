import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../widgets/telly_logo.dart';

/// Shown while the persisted session is restored (AuthStepStatus.initializing).
/// Matches the native launch screen (120 dp tile), so the hand-off is seamless.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      body: const Center(child: TellyLogo(size: 120)),
    );
  }
}
