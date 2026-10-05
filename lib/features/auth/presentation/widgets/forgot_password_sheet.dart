import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../controllers/auth_controller.dart';

/// Requests a password recovery email (FE-AUTH-03). The emailed link reopens the app
/// signed in, and the router sends the user to the reset-password screen.
class ForgotPasswordSheet extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordSheet({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _sentTo;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _localError = 'Please enter a valid email address.');
      return;
    }
    final notifier = ref.read(authControllerProvider.notifier)..clearError();
    setState(() {
      _localError = null;
      _sending = true;
    });
    final sent = await notifier.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent) _sentTo = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _localError ?? ref.watch(authControllerProvider).errorMessage;
    final sentTo = _sentTo;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Reset Your Password', style: TellyTypography.titleLarge()),
          const SizedBox(height: 8),
          Text(
            "Enter your account email and we'll send you a link to choose a new password.",
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (sentTo != null)
            Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('reset-email-sent-banner'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TellyColors.phosphorLime.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TellyColors.phosphorLime.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, color: TellyColors.phosphorLime),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your inbox. If an account exists for $sentTo, a reset link is on its way.',
                        style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            TellyTextField(
              controller: _emailController,
              hintText: 'you@example.com',
              labelText: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded, color: TellyColors.textTertiary),
            ),
            if (displayError != null) ...[
              const SizedBox(height: 12),
              Text(displayError, style: TellyTypography.caption(color: TellyColors.neonCoral)),
            ],
            const SizedBox(height: 20),
            TellyPrimaryButton(
              label: 'Send Reset Link',
              isLoading: _sending,
              onPressed: _sending ? null : _send,
            ),
          ],
          if (sentTo != null) ...[
            const SizedBox(height: 20),
            TellyPrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
          ],
        ],
      ),
    );
  }
}
