import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_empty_state.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Event Detail')),
      backgroundColor: DDColors.surface,
      body: eventAsync.when(
        loading: () => const DDLoadingIndicator(centerInScreen: true),
        error: (_, __) => const DDEmptyState.error(
            message: 'Failed to load event details.'),
        data: (event) {
          if (event == null) {
            return const DDEmptyState.error(message: 'Event not found.');
          }
          return _EventDetail(event: event);
        },
      ),
    );
  }
}

class _EventDetail extends ConsumerWidget {
  final DdEvent event;

  const _EventDetail({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMotion = event.type == EventType.motion;
    final lanReachable = ref.watch(lanReachableProvider);
    final iconColor = isMotion ? DDColors.warning : DDColors.electricBlue;

    return ListView(
      padding: const EdgeInsets.all(DDSpacing.pagePadding),
      children: [
        // Event header
        DDCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
                ),
                child: Icon(
                  isMotion
                      ? Icons.directions_run
                      : Icons.doorbell_outlined,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: DDSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(event.typeLabel,
                            style: DDTypography.h3),
                        const SizedBox(width: DDSpacing.sm),
                        isMotion
                            ? const DDChip.motion()
                            : const DDChip.doorbell(),
                      ],
                    ),
                    const SizedBox(height: DDSpacing.xs),
                    Text(
                      DateFormat('EEEE, MMMM d • h:mm a')
                          .format(event.timestamp),
                      style: DDTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.md),

        // Sensor stats (motion only)
        if (event.sensorStats != null) ...[
          DDCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sensor Data', style: DDTypography.labelLg),
                const SizedBox(height: DDSpacing.md),
                _StatRow(
                  label: 'PIR Triggered',
                  value: event.sensorStats!.pirTriggered ? 'Yes' : 'No',
                  icon: Icons.sensors,
                ),
                if (event.sensorStats!.mmwaveDistance != null) ...[
                  const SizedBox(height: DDSpacing.sm),
                  _StatRow(
                    label: 'mmWave Distance',
                    value:
                        '${event.sensorStats!.mmwaveDistance!.toStringAsFixed(1)} m',
                    icon: Icons.radar,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DDSpacing.md),
        ],

        // Clip section
        DDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clip', style: DDTypography.labelLg),
              const SizedBox(height: DDSpacing.md),
              if (event.clipId != null) ...[
                if (lanReachable) ...[
                  DDButton.primary(
                    label: 'View Clip',
                    onPressed: () => context
                        .push(Routes.clipPlayerPath(event.clipId!)),
                    leading: const Icon(Icons.play_circle_outline,
                        color: DDColors.white, size: 20),
                  ),
                ] else ...[
                  const DDEmptyState.offline(
                    message:
                        'Connect to your home Wi-Fi to view this clip.',
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.videocam_off_outlined,
                        color: DDColors.textDisabled, size: 20),
                    const SizedBox(width: DDSpacing.sm),
                    Text('No clip recorded for this event',
                        style: DDTypography.body
                            .copyWith(color: DDColors.textSecondary)),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: DDSpacing.md),

        // Event metadata
        DDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: DDTypography.labelLg),
              const SizedBox(height: DDSpacing.md),
              _StatRow(
                  label: 'Event ID', value: event.id, icon: Icons.tag),
              const SizedBox(height: DDSpacing.sm),
              _StatRow(
                  label: 'Device',
                  value: event.deviceId,
                  icon: Icons.devices),
              const SizedBox(height: DDSpacing.sm),
              _StatRow(
                  label: 'Timestamp',
                  value: DateFormat('yyyy-MM-dd HH:mm:ss')
                      .format(event.timestamp),
                  icon: Icons.access_time),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DDColors.textSecondary),
        const SizedBox(width: DDSpacing.sm),
        Text(label,
            style: DDTypography.body
                .copyWith(color: DDColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: DDTypography.body,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
