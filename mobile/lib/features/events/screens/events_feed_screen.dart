import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_empty_state.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_logo.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /home/events — Events feed tab.
/// App bar: DDLogo left, device name pill right.
/// Pull-to-refresh, sections by date, event rows, FAB when on LAN.
class EventsFeedScreen extends ConsumerWidget {
  const EventsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final isLanReachable = ref.watch(lanReachableProvider);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: DDSpacing.xl,
        title: const DDLogo.appBar(showWordmark: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: _DeviceNamePill(
              name: device.displayName,
              isOnline: device.isOnline,
            ),
          ),
        ],
      ),
      floatingActionButton: isLanReachable
          ? FloatingActionButton.extended(
              onPressed: () => context.go(Routes.homeLive),
              backgroundColor: DDColors.hunterGreen,
              icon: const Icon(Icons.videocam, color: DDColors.white, size: 20),
              label: Text(
                'LIVE',
                style: DDTypography.label.copyWith(
                  color: DDColors.white,
                  letterSpacing: 1.0,
                ),
              ),
            )
          : null,
      body: eventsAsync.when(
        loading: () => ListView(
          children: List.generate(5, (_) => const DDShimmerTile()),
        ),
        error: (_, __) => DDEmptyState.error(
          action: DDButton.secondary(
            label: 'Retry',
            onPressed: () => ref.refresh(eventsProvider.future),
            fullWidth: false,
          ),
          message: 'Failed to load events.',
        ),
        data: (events) {
          if (events.isEmpty) return const DDEmptyState.events();
          return RefreshIndicator(
            color: DDColors.hunterGreen,
            onRefresh: () => ref.refresh(eventsProvider.future),
            child: _EventsList(events: events),
          );
        },
      ),
    );
  }
}

class _DeviceNamePill extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _DeviceNamePill({required this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DDColors.softGreenGray,
        borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
        border: Border.all(color: DDColors.borderDefault, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isOnline ? DDColors.online : DDColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: DDTypography.label.copyWith(color: DDColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<DdEvent> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    // Group events by date label
    final sections = <MapEntry<String, List<DdEvent>>>[];
    final seen = <String>{};
    for (final event in events) {
      final label = _dateLabel(event.timestamp);
      if (!seen.contains(label)) {
        seen.add(label);
        sections.add(MapEntry(label, []));
      }
      sections.last.value.add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.value.length),
      itemBuilder: (context, index) {
        int i = 0;
        for (final section in sections) {
          if (index == i) return _SectionHeader(label: section.key);
          i++;
          for (final event in section.value) {
            if (index == i) return _EventTile(event: event);
            i++;
          }
        }
        return null;
      },
    );
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d').format(dt);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DDSpacing.xl, DDSpacing.lg, DDSpacing.xl, DDSpacing.sm),
      child: Text(
        label,
        style: DDTypography.bodyM.copyWith(
          fontWeight: FontWeight.w600,
          color: DDColors.textPrimary,
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
    final isDoorbell = event.type == EventType.doorbell;
    final iconBg = isDoorbell ? DDColors.doorbellEventBg : DDColors.motionEventBg;
    final icon = isDoorbell ? Icons.doorbell_outlined : Icons.directions_run;
    final iconColor =
        isDoorbell ? DDColors.doorbellEventChip : DDColors.motionEventChip;

    return InkWell(
      onTap: () => context.push(Routes.eventDetailPath(event.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.xl,
          vertical: DDSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: DDSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.typeLabel,
                    style: DDTypography.bodyM
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _relativeTime(event.timestamp),
                    style: DDTypography.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                isDoorbell
                    ? const DDChip.doorbell()
                    : const DDChip.motion(),
                if (event.clipId != null) ...[
                  const SizedBox(height: 4),
                  const DDChip.clipAvailable(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('h:mm a').format(dt);
  }
}
