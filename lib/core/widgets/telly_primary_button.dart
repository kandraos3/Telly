import 'package:flutter/material.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Primary call-to-action button with signature Phosphor Lime fill and neon glow.
/// Conforms to `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §5.1.
class TellyPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color textColor;

  const TellyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52.0,
    this.borderRadius = 14.0,
    this.backgroundColor = TellyColors.phosphorLime,
    this.textColor = const Color(0xFF08090C),
  });

  @override
  State<TellyPrimaryButton> createState() => _TellyPrimaryButtonState();
}

class _TellyPrimaryButtonState extends State<TellyPrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final bgColor = isEnabled
        ? widget.backgroundColor
        : TellyColors.strokeSubtle; // #242938

    final textColor = isEnabled
        ? widget.textColor
        : TellyColors.textTertiary; // #7D8198

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: widget.backgroundColor.withValues(alpha: _isPressed ? 0.45 : 0.25),
                  blurRadius: _isPressed ? 24.0 : 16.0,
                  spreadRadius: _isPressed ? 2.0 : 0.0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: isEnabled ? widget.onPressed : null,
          onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: () => setState(() => _isPressed = false),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.titleMedium(color: textColor).copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

