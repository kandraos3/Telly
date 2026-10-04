import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../controllers/auth_controller.dart';

/// SCR-01: Onboarding Splash & Authentication Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §1 (`SCR-01`).
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  void _openEmailAuthSheet(BuildContext context, WidgetRef ref) {
    ref.read(authControllerProvider.notifier).clearError();
    TellyFrostedSheet.show(
      context: context,
      builder: (sheetContext) => const EmailAuthSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                  // 3. Email Button (Ghost bordered)
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
                        onTap: isBusy ? null : () => _openEmailAuthSheet(context, ref),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.mail_outline_rounded, color: TellyColors.textPrimary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Email',
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
                      style: TellyTypography.caption(color: TellyColors.textPrimary),
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

/// Frosted sheet supporting both Email Sign In and Email Sign Up.
class EmailAuthSheet extends ConsumerStatefulWidget {
  const EmailAuthSheet({super.key});

  @override
  ConsumerState<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends ConsumerState<EmailAuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _localError = null;
    });
    ref.read(authControllerProvider.notifier).clearError();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _localError = 'Please enter your email.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _localError = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }

    if (_isSignUp) {
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        setState(() => _localError = 'Passwords do not match.');
        return;
      }
    }

    setState(() => _localError = null);

    final notifier = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      final hasSession = await notifier.signUpWithEmail(email: email, password: password);
      if (hasSession && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      final success = await notifier.signInWithEmail(email: email, password: password);
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.status == AuthStepStatus.authenticating;
    final displayError = _localError ?? authState.errorMessage;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isSignUp ? 'Create an Account' : 'Sign In with Email',
            style: TellyTypography.titleLarge(),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
                ? 'Join Telly to build and share your personal TV canon.'
                : 'Welcome back. Enter your credentials to continue.',
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TellyTextField(
            controller: _emailController,
            hintText: 'you@example.com',
            labelText: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: TellyColors.textTertiary),
          ),
          const SizedBox(height: 16),
          TellyTextField(
            controller: _passwordController,
            hintText: '••••••••',
            labelText: 'Password',
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: TellyColors.textTertiary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: TellyColors.textTertiary,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            TellyTextField(
              controller: _confirmPasswordController,
              hintText: '••••••••',
              labelText: 'Confirm Password',
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: TellyColors.textTertiary),
            ),
          ],
          if (displayError != null) ...[
            const SizedBox(height: 12),
            Text(
              displayError,
              style: TellyTypography.caption(color: TellyColors.neonCoral),
            ),
          ],
          const SizedBox(height: 20),
          TellyPrimaryButton(
            label: _isSignUp ? 'Create Account' : 'Sign In',
            isLoading: isBusy,
            onPressed: isBusy ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isBusy ? null : _toggleMode,
            child: Text(
              _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
              style: TellyTypography.bodyMedium(color: TellyColors.phosphorLime),
            ),
          ),
        ],
      ),
    );
  }
}
