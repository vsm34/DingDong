import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDChipVariant { motion, doorbell, online, offline, unknown, info }

/// DDChip — event-type badge and status chip
class DDChip extends StatelessWidget {
  final String label;
  final DDChipVariant variant;

  const DDChip({
    super.key,
    required this.label,
    required this.variant,
  });

  const DDChip.motion({super.key})
      : label = 'Motion',
        variant = DDChipVariant.motion;

  const DDChip.doorbell({super.key})
      : label = 'Doorbell',
        variant = DDChipVariant.doorbell;

  const DDChip.online({super.key})
      : label = 'Online',
        variant = DDChipVariant.online;

  const DDChip.offline({super.key})
      : label = 'Offline',
        variant = DDChipVariant.offline;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.sm,
        vertical: DDSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.$2,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DDSpacing.xs),
          Text(
            label,
            style: DDTypography.captionBold.copyWith(color: colors.$2),
          ),
        ],
      ),
    );
  }

  /// Returns (background, foreground) colors
  (Color, Color) _resolveColors() {
    switch (variant) {
      case DDChipVariant.motion:
        return (
          DDColors.warning.withValues(alpha: 0.12),
          DDColors.warning,
        );
      case DDChipVariant.doorbell:
        return (
          DDColors.electricBlue.withValues(alpha: 0.12),
          DDColors.electricBlue,
        );
      case DDChipVariant.online:
        return (
          DDColors.online.withValues(alpha: 0.12),
          DDColors.online,
        );
      case DDChipVariant.offline:
        return (
          DDColors.offline.withValues(alpha: 0.12),
          DDColors.offline,
        );
      case DDChipVariant.unknown:
        return (
          DDColors.unknown.withValues(alpha: 0.12),
          DDColors.unknown,
        );
      case DDChipVariant.info:
        return (
          DDColors.info.withValues(alpha: 0.12),
          DDColors.info,
        );
    }
  }
}
