import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDButtonVariant { primary, secondary, destructive }

/// DDButton — per PRD Section 5.6
/// Three variants: primary (green), secondary (outlined green), destructive (red tint)
class DDButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DDButtonVariant variant;
  final Widget? leading;
  final bool isLoading;
  final bool fullWidth;

  const DDButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DDButtonVariant.primary,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
  });

  const DDButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = DDButtonVariant.primary;

  const DDButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = DDButtonVariant.secondary;

  const DDButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = DDButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    switch (variant) {
      case DDButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: DDSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled
                  ? DDColors.hunterGreen.withValues(alpha: 0.4)
                  : DDColors.hunterGreen,
              foregroundColor: DDColors.white,
              minimumSize: const Size(0, DDSpacing.buttonHeight),
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: DDSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              elevation: 0,
            ),
            child: _buildChild(DDColors.white),
          ),
        );

      case DDButtonVariant.secondary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: DDSpacing.buttonHeight,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: disabled
                  ? DDColors.hunterGreen.withValues(alpha: 0.4)
                  : DDColors.hunterGreen,
              minimumSize: const Size(0, DDSpacing.buttonHeight),
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: DDSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              side: BorderSide(
                color: disabled
                    ? DDColors.hunterGreen.withValues(alpha: 0.4)
                    : DDColors.hunterGreen,
              ),
            ),
            child: _buildChild(
                disabled ? DDColors.hunterGreen.withValues(alpha: 0.4) : DDColors.hunterGreen),
          ),
        );

      case DDButtonVariant.destructive:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: DDSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: DDColors.error,
              minimumSize: const Size(0, DDSpacing.buttonHeight),
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: DDSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              elevation: 0,
            ),
            child: _buildChild(
                disabled ? DDColors.error.withValues(alpha: 0.4) : DDColors.error),
          ),
        );
    }
  }

  Widget _buildChild(Color color) {
    final style = DDTypography.label.copyWith(color: color);
    if (isLoading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (leading != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading!,
          const SizedBox(width: DDSpacing.sm),
          Text(label, style: style),
        ],
      );
    }
    return Text(label, style: style);
  }
}
