import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_empty_state.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_logo.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/pulsing_dot.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /home/events — Events feed tab.
/// Dashboard card at top. Pull-to-refresh, sections by date, swipe-to-delete, FAB when on LAN.
class EventsFeedScreen extends ConsumerStatefulWidget {
  const EventsFeedScreen({super.key});

  @override
  ConsumerState<EventsFeedScreen> createState() => _EventsFeedScreenState();
}

class _EventsFeedScreenState extends ConsumerState<EventsFeedScreen> {
  final _deletedIds = <String>{};
  final _filterTypes = <EventType>{};

  void _showFilterSheet(BuildContext context) {
    DDBottomSheet.show(
      context: context,
      title: 'Filter Events',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Show only:', style: DDTypography.caption.copyWith(
              color: DDColors.textMuted,
            )),
            const SizedBox(height: DDSpacing.sm),
            Wrap(
              spacing: DDSpacing.sm,
              children: [
                FilterChip(
                  label: const Text('Doorbell'),
                  selected: _filterTypes.contains(EventType.doorbell),
                  selectedColor: DDColors.hunterGreen,
                  labelStyle: TextStyle(
                    color: _filterTypes.contains(EventType.doorbell)
                        ? DDColors.white
                        : DDColors.textPrimary,
                  ),
                  onSelected: (v) {
                    setSheetState(() {
                      setState(() {
                        if (v) {
                          _filterTypes.add(EventType.doorbell);
                        } else {
                          _filterTypes.remove(EventType.doorbell);
                        }
                      });
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Motion'),
                  selected: _filterTypes.contains(EventType.motion),
                  selectedColor: DDColors.hunterGreen,
                  labelStyle: TextStyle(
                    color: _filterTypes.contains(EventType.motion)
                        ? DDColors.white
                        : DDColors.textPrimary,
                  ),
                  onSelected: (v) {
                    setSheetState(() {
                      setState(() {
                        if (v) {
                          _filterTypes.add(EventType.motion);
                        } else {
                          _filterTypes.remove(EventType.motion);
                        }
                      });
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: DDSpacing.lg),
            DDButton.secondary(
              label: 'Clear Filters',
              onPressed: () {
                setState(() => _filterTypes.clear());
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _markAllRead(BuildContext context) {
    Hive.box('settings')
        .put('lastReadTs', DateTime.now().millisecondsSinceEpoch);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All events marked as read',
            style: DDTypography.bodyM.copyWith(color: DDColors.white)),
        backgroundColor: DDColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _dismissEvent(BuildContext context, DdEvent event) {
    setState(() => _deletedIds.add(event.id));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Event deleted', style: DDTypography.bodyM.copyWith(color: DDColors.white)),
          backgroundColor: DDColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            textColor: DDColors.amber,
            onPressed: () {
              setState(() => _deletedIds.remove(event.id));
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final clipsAsync = ref.watch(clipsProvider);
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
          IconButton(
            icon: Badge(
              isLabelVisible: _filterTypes.isNotEmpty,
              backgroundColor: DDColors.hunterGreen,
              child: const Icon(Icons.filter_list,
                  color: DDColors.textPrimary, size: 22),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: DDColors.textPrimary),
            onSelected: (v) {
              if (v == 'mark_read') _markAllRead(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'mark_read',
                child: Text('Mark all as read'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: _DeviceNamePill(
              name: device.displayName,
              isOnline: isLanReachable,
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
          children: [
            _DashboardCard(
              device: device,
              isLanReachable: isLanReachable,
              todayCount: null,
              clipCount: null,
              lastMotion: null,
            ),
            ...List.generate(5, (_) => const DDShimmerTile()),
          ],
        ),
        error: (_, __) => DDEmptyState.error(
          action: DDButton.secondary(
            label: 'Retry',
            onPressed: () => ref.refresh(eventsProvider.future),
            fullWidth: false,
          ),
          message: 'Failed to load events.',
        ),
        data: (allEvents) {
          final events = allEvents
              .where((e) =>
                  !_deletedIds.contains(e.id) &&
                  (_filterTypes.isEmpty ||
                      _filterTypes.contains(e.type)))
              .toList();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayCount =
              events.where((e) => !e.timestamp.isBefore(today)).length;
          final motionEvents = events
              .where((e) => e.type == EventType.motion)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final lastMotion =
              motionEvents.isNotEmpty ? motionEvents.first.timestamp : null;
          final clipCount = clipsAsync.valueOrNull?.length;

          final dashboard = _DashboardCard(
            device: device,
            isLanReachable: isLanReachable,
            todayCount: events.isEmpty ? null : todayCount,
            clipCount: clipCount,
            lastMotion: lastMotion,
          );

          if (events.isEmpty) {
            return Column(
              children: [
                dashboard,
                const Expanded(child: DDEmptyState.events()),
              ],
            );
          }
          return RefreshIndicator(
            color: DDColors.hunterGreen,
            onRefresh: () => ref.refresh(eventsProvider.future),
            child: _EventsList(
              events: events,
              header: dashboard,
              onDismiss: (e) => _dismissEvent(context, e),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final dynamic device;
  final bool isLanReachable;
  // null = loading/empty (show dashes)
  final int? todayCount;
  final int? clipCount;
  final DateTime? lastMotion;

  const _DashboardCard({
    required this.device,
    required this.isLanReachable,
    required this.todayCount,
    required this.clipCount,
    required this.lastMotion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DDSpacing.xl, DDSpacing.lg, DDSpacing.xl, DDSpacing.sm),
      child: DDCard(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        (device as dynamic).displayName as String,
                        style: DDTypography.h3),
                  ),
                  isLanReachable
                      ? const DDChip.online()
                      : const DDChip.offline(),
                ],
              ),
              const SizedBox(height: DDSpacing.sm),
              Row(
                children: [
                  _StatBadge(
                    icon: Icons.notifications_outlined,
                    label: todayCount != null ? '$todayCount today' : '— today',
                    color: DDColors.hunterGreen,
                  ),
                  const SizedBox(width: DDSpacing.sm),
                  _StatBadge(
                    icon: Icons.video_library_outlined,
                    label: clipCount != null ? '$clipCount clips' : '— clips',
                    color: DDColors.textMuted,
                  ),
                  if (lastMotion != null) ...[
                    const SizedBox(width: DDSpacing.sm),
                    _StatBadge(
                      icon: Icons.directions_run,
                      label: _relativeShort(lastMotion!),
                      color: DDColors.motionIconBg,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeShort(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: DDTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
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
          PulsingDot(isOnline: isOnline),
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
  final Widget header;
  final void Function(DdEvent) onDismiss;

  const _EventsList({
    required this.events,
    required this.header,
    required this.onDismiss,
  });

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

    final totalItems =
        1 + sections.fold<int>(0, (sum, s) => sum + 1 + s.value.length);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        int i = 1;
        for (final section in sections) {
          if (index == i) return _SectionHeader(label: section.key);
          i++;
          for (final event in section.value) {
            if (index == i) {
              return _EventTile(event: event, onDismiss: onDismiss);
            }
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
  final void Function(DdEvent) onDismiss;

  const _EventTile({required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDoorbell = event.type == EventType.doorbell;
    final accentColor =
        isDoorbell ? DDColors.doorbellIconBg : DDColors.motionIconBg;
    final icon = isDoorbell ? Icons.doorbell_outlined : Icons.directions_run;

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDismiss(event),
      background: Container(
        alignment: Alignment.centerRight,
        color: DDColors.error,
        padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
        child: const Icon(Icons.delete_outline, color: DDColors.white, size: 24),
      ),
      child: InkWell(
        onTap: () => context.push(Routes.eventDetailPath(event.id)),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
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
                    color: accentColor,
                    borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: DDColors.white, size: 22),
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
