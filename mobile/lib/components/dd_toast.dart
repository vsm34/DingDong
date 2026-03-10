import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDToastType { success, error, info }

/// DDToast — non-blocking feedback toast shown via SnackBar
class DDToast {
  static void show(
    BuildContext context, {
    required String message,
    DDToastType type = DDToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final (bgColor, icon) = switch (type) {
      DDToastType.success => (DDColors.success, Icons.check_circle_outline),
      DDToastType.error => (DDColors.error, Icons.error_outline),
      DDToastType.info => (DDColors.navyPrimary, Icons.info_outline),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: DDColors.white, size: 20),
              const SizedBox(width: DDSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: DDTypography.body.copyWith(color: DDColors.white),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          margin: const EdgeInsets.all(DDSpacing.md),
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
