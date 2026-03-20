import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDToastType { success, error, info }

/// DDToast — per PRD Section 5.6
/// background: #1A2E1A, text: #FFFFFF, radius: full
/// padding: 12px 20px, max-width: 320px
/// auto-dismiss: 3 seconds
/// success variant: leading green check icon
/// error variant: leading red X icon
/// position: bottom center, 24px from bottom nav
class DDToast {
  static void show(
    BuildContext context, {
    required String message,
    DDToastType type = DDToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final icon = switch (type) {
      DDToastType.success => Icons.check_circle_outline,
      DDToastType.error => Icons.cancel_outlined,
      DDToastType.info => Icons.info_outline,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: DDColors.white, size: 18),
                const SizedBox(width: DDSpacing.sm),
                Flexible(
                  child: Text(
                    message,
                    style: DDTypography.bodyM.copyWith(color: DDColors.white),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: DDColors.textPrimary,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          margin: const EdgeInsets.only(
            bottom: DDSpacing.xl,
            left: DDSpacing.lg,
            right: DDSpacing.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: DDToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: DDToastType.error);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: DDToastType.info);
}
