import 'package:flutter/material.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Styled text input field for Telly dark UI with neon focus glow and error state.
/// Conforms to `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §5.
class TellyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final FocusNode? focusNode;

  const TellyTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TellyTypography.bodyLarge(color: TellyColors.textPrimary),
      cursorColor: TellyColors.phosphorLime,
      decoration: InputDecoration(
        filled: true,
        fillColor: TellyColors.backgroundCard, // #1A1D27
        hintText: hintText,
        hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
        labelText: labelText,
        labelStyle: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
        errorText: errorText,
        errorStyle: TellyTypography.caption(color: TellyColors.neonCoral),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TellyColors.strokeSubtle, // #242938
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TellyColors.phosphorLime,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TellyColors.neonCoral,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TellyColors.neonCoral,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

