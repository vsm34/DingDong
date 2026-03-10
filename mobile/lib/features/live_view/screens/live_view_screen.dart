import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_empty_state.dart';
import '../../../providers/providers.dart';

/// /home/live — Live MJPEG view stub (Phase 3 implementation)
class LiveViewScreen extends ConsumerWidget {
  const LiveViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lanReachable = ref.watch(lanReachableProvider);
    final device = ref.watch(deviceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live View')),
      backgroundColor: DDColors.surface,
      body: !lanReachable
          ? const DDEmptyState.offline(
              message: 'Live View is only available on your home Wi-Fi.',
            )
          : !device.isOnline
              ? DDEmptyState.offline(
                  message: 'Device is offline. ${device.lastSeenLabel}.',
                )
              : Column(
                  children: [
                    // Video area placeholder
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: DDColors.navyDark,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_outlined,
                                  size: 48,
                                  color: DDColors.textOnDarkSecondary),
                              const SizedBox(height: DDSpacing.sm),
                              Text(
                                'MJPEG stream',
                                style: DDTypography.body.copyWith(
                                    color: DDColors.textOnDarkSecondary),
                              ),
                              const SizedBox(height: DDSpacing.xs),
                              Text(
                                'http://dingdong-${device.deviceId}.local/stream',
                                style: DDTypography.caption.copyWith(
                                    color: DDColors.textOnDarkSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(DDSpacing.pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(DDSpacing.md),
                              decoration: BoxDecoration(
                                color: DDColors.warning.withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(DDSpacing.radiusMd),
                                border: Border.all(
                                    color:
                                        DDColors.warning.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.construction_outlined,
                                      color: DDColors.warning, size: 20),
                                  const SizedBox(width: DDSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Live View ships in Phase 3. The MJPEG stream viewer will render here.',
                                      style: DDTypography.bodySm.copyWith(
                                          color: DDColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: DDSpacing.xl),
                            Text('Stream Info',
                                style: DDTypography.labelLg),
                            const SizedBox(height: DDSpacing.sm),
                            const _InfoRow(
                                label: 'Resolution',
                                value: '320×240 or 640×480'),
                            const _InfoRow(
                                label: 'Protocol', value: 'MJPEG'),
                            const _InfoRow(
                                label: 'Network',
                                value: 'LAN only'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DDSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: DDTypography.body
                    .copyWith(color: DDColors.textSecondary)),
          ),
          Text(value, style: DDTypography.body),
        ],
      ),
    );
  }
}
