import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDEmptyStateType { events, clips, error, offline }

/// DDEmptyState — illustrated empty states for Events, Clips, Error, Offline
class DDEmptyState extends StatelessWidget {
  final DDEmptyStateType type;
  final String? title;
  final String? message;
  final Widget? action;

  const DDEmptyState({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.action,
  });

  const DDEmptyState.events({
    super.key,
    this.action,
  })  : type = DDEmptyStateType.events,
        title = 'No Events Yet',
        message = 'Motion and doorbell events\nwill appear here.';

  const DDEmptyState.clips({
    super.key,
    this.action,
  })  : type = DDEmptyStateType.clips,
        title = 'No Clips Yet',
        message = 'Recorded clips will appear\nhere once motion is detected.';

  const DDEmptyState.offline({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.offline,
        title = 'Device Unreachable';

  const DDEmptyState.error({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.error,
        title = 'Something Went Wrong';

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      DDEmptyStateType.events => (Icons.notifications_none_outlined, DDColors.electricBlue),
      DDEmptyStateType.clips => (Icons.videocam_outlined, DDColors.electricBlue),
      DDEmptyStateType.error => (Icons.error_outline, DDColors.error),
      DDEmptyStateType.offline => (Icons.cloud_off_outlined, DDColors.textSecondary),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DDSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: DDSpacing.md),
            Text(
              title ?? '',
              style: DDTypography.h3,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: DDSpacing.sm),
              Text(
                message!,
                style: DDTypography.body
                    .copyWith(color: DDColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DDSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
