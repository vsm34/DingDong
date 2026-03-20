import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /events/:eventId — Event detail.
/// Hero banner (doorbell/motion), sensor stats, Play Clip button.
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text('Event', style: DDTypography.h3),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline, color: DDColors.error),
          ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(
          child: DDLoadingIndicator(size: DDLoadingSize.lg),
        ),
        error: (_, __) => Center(
          child: Text('Error loading event', style: DDTypography.bodyM),
        ),
        data: (event) {
          if (event == null) {
            return Center(
              child: Text('Event not found', style: DDTypography.bodyM),
            );
          }
          return _EventDetailBody(event: event);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    DDConfirmSheet.show(
      context: context,
      title: 'Delete Event',
      message: 'This event will be permanently deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () {
        if (context.canPop()) context.pop();
      },
    );
  }
}

class _EventDetailBody extends ConsumerStatefulWidget {
  final DdEvent event;

  const _EventDetailBody({required this.event});

  @override
  ConsumerState<_EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends ConsumerState<_EventDetailBody> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final isDoorbell = widget.event.type == EventType.doorbell;
    final isLanReachable = ref.watch(lanReachableProvider);
    final stats = widget.event.sensorStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DDSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          isDoorbell
              ? DDCard.doorbell(
                  child: _HeroBannerContent(
                    icon: Icons.doorbell_outlined,
                    iconColor: DDColors.doorbellEventChip,
                    title: 'Doorbell Press',
                    timestamp: widget.event.timestamp,
                  ),
                )
              : DDCard.motion(
                  child: _HeroBannerContent(
                    icon: Icons.directions_run,
                    iconColor: DDColors.motionEventChip,
                    title: 'Motion Detected',
                    timestamp: widget.event.timestamp,
                  ),
                ),
          const SizedBox(height: DDSpacing.lg),
          // Sensor stats
          if (stats != null) ...[
            Text(
              'Sensor Data',
              style: DDTypography.label.copyWith(color: DDColors.textMuted),
            ),
            const SizedBox(height: DDSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIR',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: DDSpacing.xs),
                        Text(
                          stats.pirTriggered ? 'Triggered' : 'Not triggered',
                          style: DDTypography.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: stats.pirTriggered
                                ? DDColors.motionEventChip
                                : DDColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DDSpacing.md),
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'mmWave',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: DDSpacing.xs),
                        Text(
                          stats.mmwaveDistance != null
                              ? '${stats.mmwaveDistance!.toStringAsFixed(1)} m'
                              : '—',
                          style: DDTypography.bodyM
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DDSpacing.lg),
          ],
          // Play Clip
          if (widget.event.clipId != null) ...[
            DDButton.primary(
              label: isLanReachable
                  ? (_isDownloading ? 'Loading...' : 'Play Clip')
                  : 'Available on home Wi-Fi',
              onPressed: isLanReachable && !_isDownloading
                  ? () => _playClip(context)
                  : null,
              isLoading: _isDownloading,
            ),
            const SizedBox(height: DDSpacing.sm),
            Text(
              'Clip stored locally on your device.',
              style: DDTypography.caption.copyWith(color: DDColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _playClip(BuildContext context) async {
    setState(() => _isDownloading = true);
    final router = GoRouter.of(context);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isDownloading = false);
    router.push(Routes.clipPlayerPath(widget.event.clipId!));
  }
}

class _HeroBannerContent extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final DateTime timestamp;

  const _HeroBannerContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(width: DDSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DDTypography.h2),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy · h:mm a').format(timestamp),
                style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
