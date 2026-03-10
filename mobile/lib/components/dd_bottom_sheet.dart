import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDBottomSheet — action/confirmation/settings bottom sheets
class DDBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  const DDBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
  });

  /// Show the bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      isScrollControlled: true,
      backgroundColor: DDColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DDSpacing.radiusXl),
        ),
      ),
      builder: (_) => DDBottomSheet(
        title: title,
        subtitle: subtitle,
        actions: actions,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DDSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DDColors.divider,
                borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DDSpacing.pagePadding,
                DDSpacing.md,
                DDSpacing.pagePadding,
                0,
              ),
              child: Text(title!, style: DDTypography.h2),
            ),
          ],
          if (subtitle != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DDSpacing.pagePadding,
                DDSpacing.xs,
                DDSpacing.pagePadding,
                0,
              ),
              child: Text(subtitle!, style: DDTypography.bodySm),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(DDSpacing.pagePadding),
            child: child,
          ),
          if (actions != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(DDSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions!,
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Confirmation bottom sheet helper
class DDConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const DDConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DDColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DDSpacing.radiusXl),
        ),
      ),
      builder: (_) => DDConfirmSheet(
        title: title,
        message: message,
        onConfirm: onConfirm,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DDSpacing.pagePadding,
        DDSpacing.md,
        DDSpacing.pagePadding,
        DDSpacing.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DDColors.divider,
                borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: DDSpacing.md),
          Text(title, style: DDTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: DDSpacing.sm),
          Text(message,
              style: DDTypography.body
                  .copyWith(color: DDColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: DDSpacing.lg),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? DDColors.error : DDColors.navyPrimary,
              minimumSize:
                  const Size(double.infinity, DDSpacing.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
            ),
            child: Text(confirmLabel, style: DDTypography.button.copyWith(color: DDColors.white)),
          ),
          const SizedBox(height: DDSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, DDSpacing.buttonHeight),
            ),
            child: Text(cancelLabel,
                style: DDTypography.button
                    .copyWith(color: DDColors.textSecondary)),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
