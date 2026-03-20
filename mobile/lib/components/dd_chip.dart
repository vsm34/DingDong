import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDChipVariant { motion, doorbell, online, offline, clipAvailable }

/// DDChip — per PRD Section 5.6
/// Motion:   background #DCFCE7, text #065F46
/// Doorbell: background #FEF3C7, text #92400E
/// Online:   background #DCFCE7, text #166534, with green dot 6px
/// Offline:  background #FEE2E2, text #991B1B, with red dot 6px
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

  const DDChip.clipAvailable({super.key})
      : label = 'Clip',
        variant = DDChipVariant.clipAvailable;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, showDot, dotColor) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.sm,
        vertical: DDSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DDSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DDSpacing.xs),
          ],
          Text(
            label,
            style: DDTypography.label.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  /// Returns (bg, fg, showDot, dotColor)
  (Color, Color, bool, Color) _resolve() {
    switch (variant) {
      case DDChipVariant.motion:
        return (
          const Color(0xFFDCFCE7),
          DDColors.motionEventChip,
          false,
          Colors.transparent,
        );
      case DDChipVariant.doorbell:
        return (
          const Color(0xFFFEF3C7),
          DDColors.doorbellEventChip,
          false,
          Colors.transparent,
        );
      case DDChipVariant.online:
        return (
          const Color(0xFFDCFCE7),
          DDColors.online,
          true,
          DDColors.online,
        );
      case DDChipVariant.offline:
        return (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          true,
          DDColors.error,
        );
      case DDChipVariant.clipAvailable:
        return (
          DDColors.clipAvailable,
          DDColors.clipText,
          false,
          Colors.transparent,
        );
    }
  }
}
