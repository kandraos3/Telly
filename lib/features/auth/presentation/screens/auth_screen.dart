import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../controllers/auth_controller.dart';
import 'handle_reservation_screen.dart';

/// SCR-01: Onboarding Splash & Authentication Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §1 (`SCR-01`).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _openPhoneAuthSheet(BuildContext context) {
    TellyFrostedSheet.show(
      context: context,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authControllerProvider);
            final isAwaitingOtp = authState.status == AuthStepStatus.awaitingOtp;
            final isBusy = authState.status == AuthStepStatus.authenticating;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAwaitingOtp ? 'Enter 6-Digit Code' : 'Sign In with Phone',
                    style: TellyTypography.titleLarge(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAwaitingOtp
                        ? 'We sent a verification code to ${authState.phoneNumber}'
                        : 'We will send a 6-digit verification code via SMS.',
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (!isAwaitingOtp) ...[
                    TellyTextField(
                      controller: _phoneController,
                      hintText: '+1 (555) 000-0000',
                      labelText: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, color: TellyColors.textTertiary),
                    ),
                    const SizedBox(height: 16),
                    TellyPrimaryButton(
                      label: 'Send Verification Code',
                      isLoading: isBusy,
                      onPressed: () {
                        if (_phoneController.text.trim().isNotEmpty) {
                          ref
                              .read(authControllerProvider.notifier)
                              .requestPhoneOtp(_phoneController.text.trim());
                        }
                      },
                    ),
                  ] else ...[
                    TellyTextField(
                      controller: _otpController,
                      hintText: '123456',
                      labelText: '6-Digit SMS Code',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.lock_clock_outlined, color: TellyColors.textTertiary),
                    ),
                    if (authState.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        authState.errorMessage!,
                        style: TellyTypography.caption(color: TellyColors.neonCoral),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TellyPrimaryButton(
                      label: 'Verify & Continue',
                      isLoading: isBusy,
                      onPressed: () async {
                        final success = await ref
                            .read(authControllerProvider.notifier)
                            .verifyOtp(_otpController.text.trim());
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (success && mounted) {
                          _navigateToHandleReservation();
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToHandleReservation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HandleReservationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStepStatus.authenticated && mounted) {
        _navigateToHandleReservation();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.status == AuthStepStatus.authenticating;

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      body: Stack(
        children: [
          // Background ambient radial glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TellyColors.phosphorLime.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TellyColors.neonCoral.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),

                  // Brand Hero & Tagline
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: const Center(
                        child: Text(
                          '📺',
                          style: TextStyle(fontSize: 34),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'TELLY',
                      style: TellyTypography.displayXXL().copyWith(
                        letterSpacing: 4.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Your Personal TV Canon.\nRanked, Shared, Settled.',
                      textAlign: TextAlign.center,
                      style: TellyTypography.displayXL().copyWith(
                        fontSize: 20,
                        height: 1.4,
                        color: TellyColors.textSecondary,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Social Auth Stack
                  // 1. Apple Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isBusy
                            ? null
                            : () => ref.read(authControllerProvider.notifier).signInWithApple(),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.apple, color: Colors.black, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Apple',
                                style: TellyTypography.titleMedium(color: Colors.black).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Google Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TellyColors.strokeSubtle),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isBusy
                            ? null
                            : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: TellyTypography.titleMedium(color: Colors.white).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Phone Button (Ghost bordered)
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TellyColors.strokeStrong),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isBusy ? null : () => _openPhoneAuthSheet(context),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_iphone, color: TellyColors.textPrimary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Phone Number',
                                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy.',
                      style: TellyTypography.caption(color: TellyColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
