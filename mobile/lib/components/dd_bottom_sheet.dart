import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';
import 'dd_button.dart';

/// DDBottomSheet — per PRD Section 5.6
/// background: #FFFFFF, radius: lg (12px) top corners only
/// drag handle: 4px × 32px, #E0E0DC, centered, 12px from top
/// padding: 24px, max-height: 80% screen
/// backdrop: rgba(0,0,0,0.4) with fade animation
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
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DDSpacing.radiusLg),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: DDSpacing.md),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: DDColors.borderDefault,
                  borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
                ),
              ),
            ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DDSpacing.lg,
                  DDSpacing.md,
                  DDSpacing.lg,
                  0,
                ),
                child: Text(title!, style: DDTypography.h2),
              ),
            ],
            if (subtitle != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DDSpacing.lg,
                  DDSpacing.xs,
                  DDSpacing.lg,
                  0,
                ),
                child: Text(
                  subtitle!,
                  style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
                ),
              ),
            ],
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(DDSpacing.lg),
                child: child,
              ),
            ),
            if (actions != null) ...[
              const Divider(height: 1, thickness: 0.5),
              Padding(
                padding: const EdgeInsets.all(DDSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions!,
                ),
              ),
            ],
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// DDConfirmSheet — confirmation bottom sheet with destructive or normal confirm
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
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DDSpacing.radiusLg),
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
      padding: EdgeInsets.fromLTRB(
        DDSpacing.lg,
        DDSpacing.md,
        DDSpacing.lg,
        DDSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: DDColors.borderDefault,
                borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: DDSpacing.md),
          Text(title, style: DDTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: DDSpacing.sm),
          Text(
            message,
            style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DDSpacing.lg),
          isDestructive
              ? DDButton.destructive(
                  label: confirmLabel,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm();
                  },
                )
              : DDButton.primary(
                  label: confirmLabel,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm();
                  },
                ),
          const SizedBox(height: DDSpacing.sm),
          DDButton.secondary(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
