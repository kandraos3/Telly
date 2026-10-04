import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../controllers/auth_controller.dart';
import '../controllers/handle_reservation_controller.dart';

/// Handle reservation (FE-107). Business state lives in [handleReservationProvider];
/// this widget only owns its text controllers.
class HandleReservationScreen extends ConsumerStatefulWidget {
  const HandleReservationScreen({super.key});

  @override
  ConsumerState<HandleReservationScreen> createState() => _HandleReservationScreenState();
}

class _HandleReservationScreenState extends ConsumerState<HandleReservationScreen> {
  final _handleController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null && user.displayName.isNotEmpty) {
      _displayNameController.text = user.displayName;
    }
  }

  @override
  void dispose() {
    _handleController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// On success the profile gains a handle and the router redirects to SCR-02 (FE-602).
  Future<void> _submitHandle() =>
      ref.read(handleReservationProvider.notifier).submit(displayName: _displayNameController.text);

  Widget? _buildSuffixIcon(HandleAvailabilityState availability) {
    switch (availability) {
      case HandleAvailabilityState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: TellyColors.phosphorLime),
          ),
        );
      case HandleAvailabilityState.available:
        return const Icon(Icons.check_circle, color: TellyColors.phosphorLime);
      case HandleAvailabilityState.unavailable:
      case HandleAvailabilityState.invalid:
        return const Icon(Icons.cancel, color: TellyColors.neonCoral);
      case HandleAvailabilityState.initial:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = ref.watch(handleReservationProvider);

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('STEP 1 OF 3', style: TellyTypography.caption(color: TellyColors.textTertiary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Claim your Telly handle',
                style: TellyTypography.displayXL(),
              ),
              const SizedBox(height: 8),
              Text(
                'This is how friends will find you, duel you, and compare taste.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Username input
              TellyTextField(
                controller: _handleController,
                hintText: 'jordan',
                labelText: 'USERNAME',
                autofocus: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Text('@', style: TextStyle(color: TellyColors.textSecondary, fontSize: 16)),
                ),
                suffixIcon: _buildSuffixIcon(reservation.availability),
                errorText: reservation.error,
                onChanged: ref.read(handleReservationProvider.notifier).onHandleChanged,
              ),

              if (reservation.availability == HandleAvailabilityState.available) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: TellyColors.phosphorLime),
                    const SizedBox(width: 4),
                    Text(
                      'Nice! @${reservation.handle} is available.',
                      style: TellyTypography.caption(color: TellyColors.phosphorLime),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Display Name input
              TellyTextField(
                controller: _displayNameController,
                hintText: 'Jordan Miller',
                labelText: 'DISPLAY NAME',
                prefixIcon: const Icon(Icons.person_outline, color: TellyColors.textTertiary),
              ),

              const Spacer(),

              TellyPrimaryButton(
                label: 'CONTINUE TO HOUSEHOLD SETUP →',
                isLoading: reservation.isSubmitting,
                onPressed: reservation.canSubmit ? _submitHandle : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
