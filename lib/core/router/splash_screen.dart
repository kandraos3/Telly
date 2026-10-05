import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Shown while the persisted session is restored (AuthStepStatus.initializing).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      body: Center(
        child: Text('TELLY', style: TellyTypography.displayXL(color: TellyColors.phosphorLime)),
      ),
    );
  }
}
