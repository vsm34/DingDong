import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_empty_state.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

class EventsFeedScreen extends ConsumerWidget {
  const EventsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.md),
            child: _OnlineChip(isOnline: device.isOnline),
          ),
        ],
      ),
      backgroundColor: DDColors.surface,
      body: RefreshIndicator(
        color: DDColors.electricBlue,
        onRefresh: () => ref.refresh(eventsProvider.future),
        child: eventsAsync.when(
          loading: () => ListView(
            children: List.generate(
                5, (_) => const DDShimmerTile()),
          ),
          error: (e, _) => DDEmptyState.error(
            action: TextButton(
              onPressed: () => ref.refresh(eventsProvider.future),
              child: const Text('Retry'),
            ),
            message: 'Failed to load events. Pull to retry.',
          ),
          data: (events) {
            if (events.isEmpty) return const DDEmptyState.events();
            return ListView.builder(
              padding: const EdgeInsets.only(
                top: DDSpacing.sm,
                bottom: DDSpacing.xl,
              ),
              itemCount: events.length,
              itemBuilder: (context, i) =>
                  _EventTile(event: events[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final DdEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isMotion = event.type == EventType.motion;
    final iconColor = isMotion ? DDColors.warning : DDColors.electricBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.md,
        vertical: DDSpacing.xs,
      ),
      child: DDEventCard(
        onTap: () => context.push(Routes.eventDetailPath(event.id)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          child: Icon(
            isMotion ? Icons.directions_run : Icons.doorbell_outlined,
            color: iconColor,
            size: 22,
          ),
        ),
        title: event.typeLabel,
        subtitle: _formatTimestamp(event.timestamp),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isMotion
                ? const DDChip.motion()
                : const DDChip.doorbell(),
            if (event.clipId != null) ...[
              const SizedBox(height: DDSpacing.xs),
              const _ClipBadge(),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) {
      return DateFormat('EEE, h:mm a').format(ts);
    }
    return DateFormat('MMM d, h:mm a').format(ts);
  }
}

class _ClipBadge extends StatelessWidget {
  const _ClipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: DDColors.navyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined,
              size: 10, color: DDColors.navyPrimary),
          const SizedBox(width: 2),
          Text('Clip',
              style: DDTypography.caption
                  .copyWith(color: DDColors.navyPrimary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  final bool isOnline;

  const _OnlineChip({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return isOnline
        ? const DDChip.online()
        : const DDChip.offline();
  }
}
