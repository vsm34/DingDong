import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDCard variants — event card, clip card, device status card
class DDCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;

  const DDCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DDSpacing.radiusLg;
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? DDColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DDColors.divider),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DDSpacing.cardPadding),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// DDEventCard — used in events feed
class DDEventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DDEventCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DDCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.md,
        vertical: DDSpacing.md,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: DDSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DDTypography.labelLg),
                const SizedBox(height: DDSpacing.xs),
                Text(subtitle, style: DDTypography.bodySm),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DDSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// DDStatusCard — device online/offline status card
class DDStatusCard extends StatelessWidget {
  final String deviceName;
  final bool isOnline;
  final String lastSeen;
  final VoidCallback? onLiveView;

  const DDStatusCard({
    super.key,
    required this.deviceName,
    required this.isOnline,
    required this.lastSeen,
    this.onLiveView,
  });

  @override
  Widget build(BuildContext context) {
    return DDCard(
      backgroundColor: DDColors.navyPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: DDTypography.h2
                          .copyWith(color: DDColors.textOnDark),
                    ),
                    const SizedBox(height: DDSpacing.xs),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                isOnline ? DDColors.online : DDColors.offline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: DDSpacing.xs),
                        Text(
                          isOnline ? 'Online' : 'Offline — $lastSeen',
                          style: DDTypography.bodySm
                              .copyWith(color: DDColors.textOnDarkSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.videocam_outlined,
                  color: DDColors.textOnDarkSecondary, size: 28),
            ],
          ),
          if (onLiveView != null) ...[
            const SizedBox(height: DDSpacing.md),
            TextButton.icon(
              onPressed: isOnline ? onLiveView : null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Live View'),
              style: TextButton.styleFrom(
                foregroundColor: isOnline
                    ? DDColors.electricBlueLight
                    : DDColors.textOnDarkSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
