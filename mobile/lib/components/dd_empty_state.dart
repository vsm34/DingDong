import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDEmptyStateType { events, clips, error, offline, connecting }

/// DDEmptyState — per PRD Section 5.6
/// Lottie animation: 160px × 160px centered
/// Title: H3, #1A2E1A, centered
/// Subtitle: Body M, #6B7280, centered, max-width 260px
/// Optional CTA: DDButton secondary variant
/// Spacing: animation → title 16px, title → subtitle 8px, subtitle → CTA 24px
class DDEmptyState extends StatelessWidget {
  final DDEmptyStateType type;
  final String? title;
  final String? message;
  final Widget? action;
  final String? lottiePath;

  const DDEmptyState({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.action,
    this.lottiePath,
  });

  const DDEmptyState.events({
    super.key,
    this.action,
  })  : type = DDEmptyStateType.events,
        title = 'No Events Yet',
        message = 'Motion and doorbell events will appear here.',
        lottiePath = null;

  const DDEmptyState.clips({
    super.key,
    this.action,
  })  : type = DDEmptyStateType.clips,
        title = 'No Clips Yet',
        message = 'Recorded clips will appear here once motion is detected.',
        lottiePath = null;

  const DDEmptyState.offline({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.offline,
        title = 'Device Unreachable',
        lottiePath = null;

  const DDEmptyState.error({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.error,
        title = 'Something Went Wrong',
        lottiePath = null;

  const DDEmptyState.connecting({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.connecting,
        title = 'Connecting...',
        lottiePath = null;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _resolveIcon();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DDSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie animation placeholder — 160x160
            // Replace Container with Lottie.asset(lottiePath!) when animation assets are added
            SizedBox(
              width: 160,
              height: 160,
              child: _buildAnimation(icon, iconColor),
            ),
            const SizedBox(height: DDSpacing.md),
            Text(
              title ?? '',
              style: DDTypography.h3,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: DDSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  message!,
                  style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
                  textAlign: TextAlign.center,
                ),
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

  Widget _buildAnimation(IconData icon, Color color) {
    // When a Lottie asset path is provided, use it
    if (lottiePath != null) {
      return Lottie.asset(
        lottiePath!,
        width: 160,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _iconFallback(icon, color),
      );
    }
    return _iconFallback(icon, color);
  }

  Widget _iconFallback(IconData icon, Color color) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 64, color: color),
    );
  }

  (IconData, Color) _resolveIcon() {
    switch (type) {
      case DDEmptyStateType.events:
        return (Icons.notifications_none_outlined, DDColors.hunterGreen);
      case DDEmptyStateType.clips:
        return (Icons.videocam_outlined, DDColors.hunterGreen);
      case DDEmptyStateType.error:
        return (Icons.error_outline, DDColors.error);
      case DDEmptyStateType.offline:
        return (Icons.cloud_off_outlined, DDColors.textMuted);
      case DDEmptyStateType.connecting:
        return (Icons.wifi_outlined, DDColors.hunterGreen);
    }
  }
}

/// Full-screen loading state with Lottie placeholder
class DDLoadingState extends StatelessWidget {
  final String? message;

  const DDLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset(
              'assets/animations/loading.json',
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) => const CircularProgressIndicator(
                color: DDColors.hunterGreen,
                strokeWidth: 2.5,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: DDSpacing.md),
            Text(
              message!,
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
