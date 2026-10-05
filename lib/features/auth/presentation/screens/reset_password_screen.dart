import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../controllers/auth_controller.dart';

/// Shown after a password recovery link opens the app (FE-AUTH-03). Saving releases the
/// router's recovery hold; signing out abandons the reset.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _localError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }
    final notifier = ref.read(authControllerProvider.notifier)..clearError();
    setState(() {
      _localError = null;
      _saving = true;
    });
    await notifier.updatePassword(password);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _localError ?? ref.watch(authControllerProvider).errorMessage;

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _saving ? null : () => ref.read(authControllerProvider.notifier).signOut(),
            child: Text('Cancel', style: TellyTypography.bodyMedium(color: TellyColors.textSecondary)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose a New Password', style: TellyTypography.titleLarge()),
              const SizedBox(height: 8),
              Text(
                "You're signed in from your reset link. Set a new password to finish.",
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TellyTextField(
                controller: _passwordController,
                hintText: '••••••••',
                labelText: 'New Password',
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: TellyColors.textTertiary),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: TellyColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 16),
              TellyTextField(
                controller: _confirmController,
                hintText: '••••••••',
                labelText: 'Confirm New Password',
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: TellyColors.textTertiary),
              ),
              if (displayError != null) ...[
                const SizedBox(height: 12),
                Text(displayError, style: TellyTypography.caption(color: TellyColors.neonCoral)),
              ],
              const SizedBox(height: 24),
              TellyPrimaryButton(label: 'Save Password', isLoading: _saving, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}
