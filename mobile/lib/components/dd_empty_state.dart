import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDEmptyStateType { events, clips, error, offline, connecting }

/// DDEmptyState — per PRD Section 5.6
/// Events: pulsing bell icon (AnimationController, scale 1.0→1.08→1.0, 2s repeat)
/// Error: static wifi_off icon in gray
/// Others: static icon fallback
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
        message = 'Motion and doorbell events will appear here.';

  const DDEmptyState.clips({
    super.key,
    this.action,
  })  : type = DDEmptyStateType.clips,
        title = 'No Clips Yet',
        message = 'Recorded clips will appear here once motion is detected.';

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

  const DDEmptyState.connecting({
    super.key,
    this.action,
    this.message,
  })  : type = DDEmptyStateType.connecting,
        title = 'Connecting...';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DDSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: _buildIcon(),
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

  Widget _buildIcon() {
    switch (type) {
      case DDEmptyStateType.events:
        return const _PulsingIcon(
          icon: Icons.notifications_outlined,
          color: DDColors.hunterGreen,
        );
      case DDEmptyStateType.clips:
        return const _StaticIcon(
          icon: Icons.video_library_outlined,
          color: DDColors.hunterGreen,
        );
      case DDEmptyStateType.error:
        return const _StaticIcon(
          icon: Icons.wifi_off_rounded,
          color: DDColors.textMuted,
        );
      case DDEmptyStateType.offline:
        return const _StaticIcon(
          icon: Icons.cloud_off_outlined,
          color: DDColors.textMuted,
        );
      case DDEmptyStateType.connecting:
        return const _StaticIcon(
          icon: Icons.wifi_outlined,
          color: DDColors.hunterGreen,
        );
    }
  }
}

/// Pulsing icon — scale oscillates 1.0→1.08→1.0 every 2 seconds.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_ctrl);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: Icon(widget.icon, size: 64, color: widget.color),
      ),
    );
  }
}

/// Static icon in a circular background.
class _StaticIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StaticIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 48, color: color),
      ),
    );
  }
}

/// Full-screen loading state with CircularProgressIndicator fallback.
class DDLoadingState extends StatelessWidget {
  final String? message;

  const DDLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: DDColors.hunterGreen,
              strokeWidth: 2.5,
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
