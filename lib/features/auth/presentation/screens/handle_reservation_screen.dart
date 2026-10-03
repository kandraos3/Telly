import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../../data/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../../../onboarding/presentation/screens/streaming_setup_screen.dart';

enum HandleAvailabilityState {
  initial,
  checking,
  available,
  unavailable,
  invalid,
}

class HandleReservationScreen extends ConsumerStatefulWidget {
  const HandleReservationScreen({super.key});

  @override
  ConsumerState<HandleReservationScreen> createState() => _HandleReservationScreenState();
}

class _HandleReservationScreenState extends ConsumerState<HandleReservationScreen> {
  final _handleController = TextEditingController();
  final _displayNameController = TextEditingController();
  Timer? _debounceTimer;
  HandleAvailabilityState _availability = HandleAvailabilityState.initial;
  String? _validationError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default display name if known from social auth
    final user = ref.read(authControllerProvider).user;
    if (user != null && user.displayName.isNotEmpty) {
      _displayNameController.text = user.displayName;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _handleController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _onHandleChanged(String value) {
    _debounceTimer?.cancel();
    final raw = value.trim();

    if (raw.isEmpty) {
      setState(() {
        _availability = HandleAvailabilityState.initial;
        _validationError = null;
      });
      return;
    }

    // Validate regex: 3 to 20 alphanumeric chars + underscores
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    if (!regex.hasMatch(raw)) {
      setState(() {
        _availability = HandleAvailabilityState.invalid;
        _validationError = raw.length < 3
            ? 'Handle must be at least 3 characters'
            : raw.length > 20
                ? 'Handle cannot exceed 20 characters'
                : 'Only letters, numbers, and underscores are allowed';
      });
      return;
    }

    setState(() {
      _availability = HandleAvailabilityState.checking;
      _validationError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final repository = ref.read(authRepositoryProvider);
      final isAvailable = await repository.checkHandleAvailable(raw);

      if (mounted) {
        setState(() {
          _availability = isAvailable
              ? HandleAvailabilityState.available
              : HandleAvailabilityState.unavailable;
          _validationError = isAvailable ? null : '@$raw is already taken';
        });
      }
    });
  }

  Future<void> _submitHandle() async {
    final handle = _handleController.text.trim();
    final displayName = _displayNameController.text.trim().isEmpty
        ? handle
        : _displayNameController.text.trim();

    if (_availability != HandleAvailabilityState.available) return;

    setState(() => _isSubmitting = true);

    final success = await ref.read(authControllerProvider.notifier).completeOnboarding(
          username: handle,
          displayName: displayName,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StreamingSetupScreen()),
        );
      }
    }
  }

  Widget? _buildSuffixIcon() {
    switch (_availability) {
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
    final canSubmit = _availability == HandleAvailabilityState.available && !_isSubmitting;

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
                suffixIcon: _buildSuffixIcon(),
                errorText: _validationError,
                onChanged: _onHandleChanged,
              ),

              if (_availability == HandleAvailabilityState.available) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: TellyColors.phosphorLime),
                    const SizedBox(width: 4),
                    Text(
                      'Nice! @${_handleController.text.trim()} is available.',
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
                isLoading: _isSubmitting,
                onPressed: canSubmit ? _submitHandle : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
