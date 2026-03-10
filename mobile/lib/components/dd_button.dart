import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDButtonVariant { primary, secondary, destructive, ghost }
enum DDButtonSize { normal, small }

/// DDButton — branded button with primary, secondary, destructive, ghost variants
class DDButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DDButtonVariant variant;
  final DDButtonSize size;
  final Widget? leading;
  final bool isLoading;
  final bool fullWidth;

  const DDButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DDButtonVariant.primary,
    this.size = DDButtonSize.normal,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
  });

  // Convenience constructors
  const DDButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
    this.size = DDButtonSize.normal,
  }) : variant = DDButtonVariant.primary;

  const DDButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
    this.size = DDButtonSize.normal,
  }) : variant = DDButtonVariant.secondary;

  const DDButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
    this.size = DDButtonSize.normal,
  }) : variant = DDButtonVariant.destructive;

  const DDButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.fullWidth = true,
    this.size = DDButtonSize.normal,
  }) : variant = DDButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final isSmall = size == DDButtonSize.small;
    final height =
        isSmall ? DDSpacing.buttonHeightSm : DDSpacing.buttonHeight;
    final labelStyle =
        isSmall ? DDTypography.buttonSm : DDTypography.button;

    final disabled = onPressed == null || isLoading;

    switch (variant) {
      case DDButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  disabled ? DDColors.textDisabled : DDColors.navyPrimary,
              foregroundColor: DDColors.white,
              minimumSize: Size(0, height),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              elevation: 0,
            ),
            child: _buildChild(labelStyle, DDColors.white),
          ),
        );

      case DDButtonVariant.secondary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  disabled ? DDColors.textDisabled : DDColors.navyPrimary,
              minimumSize: Size(0, height),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              side: BorderSide(
                  color: disabled ? DDColors.textDisabled : DDColors.navyPrimary,
                  width: 1.5),
            ),
            child: _buildChild(
                labelStyle,
                disabled ? DDColors.textDisabled : DDColors.navyPrimary),
          ),
        );

      case DDButtonVariant.destructive:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  disabled ? DDColors.textDisabled : DDColors.error,
              foregroundColor: DDColors.white,
              minimumSize: Size(0, height),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              elevation: 0,
            ),
            child: _buildChild(labelStyle, DDColors.white),
          ),
        );

      case DDButtonVariant.ghost:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: TextButton(
            onPressed: disabled ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor:
                  disabled ? DDColors.textDisabled : DDColors.electricBlue,
              minimumSize: Size(0, height),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
            ),
            child: _buildChild(
                labelStyle,
                disabled ? DDColors.textDisabled : DDColors.electricBlue),
          ),
        );
    }
  }

  Widget _buildChild(TextStyle style, Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color,
        ),
      );
    }
    if (leading != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading!,
          const SizedBox(width: DDSpacing.sm),
          Text(label, style: style.copyWith(color: color)),
        ],
      );
    }
    return Text(label, style: style.copyWith(color: color));
  }
}
