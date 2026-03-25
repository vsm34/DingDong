import 'package:firebase_auth/firebase_auth.dart';
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
  String? _filterTag;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context, List<DdEvent> allEvents) {
    // Collect up to 10 recent unique tags
    final recentTags = <String>[];
    for (final e in allEvents) {
      for (final tag in e.tags) {
        if (!recentTags.contains(tag)) recentTags.add(tag);
        if (recentTags.length >= 10) break;
      }
      if (recentTags.length >= 10) break;
    }

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
            if (recentTags.isNotEmpty) ...[
              const SizedBox(height: DDSpacing.md),
              Text('By tag:', style: DDTypography.caption.copyWith(
                color: DDColors.textMuted,
              )),
              const SizedBox(height: DDSpacing.sm),
              Wrap(
                spacing: DDSpacing.sm,
                runSpacing: DDSpacing.xs,
                children: recentTags.map((tag) {
                  final selected = _filterTag == tag;
                  return FilterChip(
                    label: Text('#$tag'),
                    selected: selected,
                    selectedColor: DDColors.hunterGreen,
                    labelStyle: TextStyle(
                      color: selected ? DDColors.white : DDColors.textPrimary,
                      fontSize: 12,
                    ),
                    onSelected: (v) {
                      setSheetState(() {
                        setState(() => _filterTag = v ? tag : null);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: DDSpacing.lg),
            DDButton.secondary(
              label: 'Clear Filters',
              onPressed: () {
                setState(() {
                  _filterTypes.clear();
                  _filterTag = null;
                });
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

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  bool _eventMatchesSearch(DdEvent event) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    if (event.typeLabel.toLowerCase().contains(q)) return true;
    if (DateFormat('MMM d, yyyy h:mm a').format(event.timestamp).toLowerCase().contains(q)) {
      return true;
    }
    if (event.tags.any((t) => t.toLowerCase().contains(q))) return true;
    return false;
  }

  void _showDeviceSwitcher(BuildContext context) {
    final devicesAsync = ref.read(userDevicesProvider);
    final activeDevice = ref.read(deviceProvider);

    DDBottomSheet.show<void>(
      context: context,
      title: 'Your Devices',
      child: devicesAsync.when(
        loading: () =>
            const Center(child: DDLoadingIndicator(size: DDLoadingSize.md)),
        error: (_, __) => Center(
            child: Text('Failed to load devices', style: DDTypography.bodyM)),
        data: (devices) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...devices.map((device) {
              final isActive = device.deviceId == activeDevice.deviceId;
              return ListTile(
                leading: PulsingDot(isOnline: device.isOnline),
                title: Text(device.displayName, style: DDTypography.bodyM),
                subtitle: Text(device.deviceId,
                    style: DDTypography.caption
                        .copyWith(color: DDColors.textMuted)),
                trailing: isActive
                    ? const Icon(Icons.check, color: DDColors.hunterGreen)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  if (!isActive) {
                    ref.read(deviceProvider.notifier).state = device;
                    ref.read(activeDeviceIdProvider.notifier).state =
                        device.deviceId;
                    Hive.box('settings')
                        .put('active_device_id', device.deviceId);
                    ref.read(tunnelUrlProvider.notifier).state = null;
                    ref.invalidate(eventsProvider);
                    ref.invalidate(clipsProvider);
                    ref.invalidate(settingsProvider);
                  }
                },
              );
            }),
            const Divider(
                height: 0.5,
                thickness: 0.5,
                color: DDColors.borderDefault),
            ListTile(
              leading: const Icon(Icons.add_circle_outline,
                  color: DDColors.hunterGreen),
              title: Text('Add new device',
                  style: DDTypography.bodyM
                      .copyWith(color: DDColors.hunterGreen)),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.onboardWelcome);
              },
            ),
          ],
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
    final tunnelUrl = ref.watch(tunnelUrlProvider);
    final isRemoteActive = tunnelUrl != null && !isLanReachable;

    final hasActiveFilter =
        _filterTypes.isNotEmpty || _filterTag != null;

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: DDSpacing.xl,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSearching
              ? TextField(
                  key: const ValueKey('search'),
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    hintStyle: DDTypography.bodyM
                        .copyWith(color: DDColors.textMuted),
                    border: InputBorder.none,
                  ),
                  style: DDTypography.bodyM,
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : const DDLogo.appBar(
                  key: ValueKey('logo'), showWordmark: true),
        ),
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close, color: DDColors.textPrimary),
                  onPressed: _clearSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search,
                      color: DDColors.textPrimary, size: 22),
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: hasActiveFilter,
                    backgroundColor: DDColors.hunterGreen,
                    child: const Icon(Icons.filter_list,
                        color: DDColors.textPrimary, size: 22),
                  ),
                  onPressed: () => _showFilterSheet(
                      context, eventsAsync.valueOrNull ?? []),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: DDColors.textPrimary),
                  onSelected: (v) {
                    if (v == 'mark_read') _markAllRead(context);
                    if (v == 'heatmap') context.push(Routes.activityHeatmap);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Text('Mark all as read'),
                    ),
                    const PopupMenuItem(
                      value: 'heatmap',
                      child: Text('View Heatmap'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: DDSpacing.xl),
                  child: GestureDetector(
                    onTap: () => _showDeviceSwitcher(context),
                    child: _DeviceNamePill(
                      name: device.displayName,
                      isOnline: isLanReachable,
                      isRemote: isRemoteActive,
                    ),
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
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          final firebaseUser =
              authSnap.data ?? FirebaseAuth.instance.currentUser;
          final isEmailVerified =
              firebaseUser?.emailVerified ?? true;
          return Column(
            children: [
              if (!isEmailVerified)
                Container(
                  width: double.infinity,
                  color: DDColors.amber.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSpacing.xl,
                    vertical: DDSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: DDColors.warning),
                      const SizedBox(width: DDSpacing.sm),
                      Expanded(
                        child: Text(
                          'Please verify your email address.',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.warning),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await firebaseUser?.sendEmailVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent.'),
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: DDColors.hunterGreen,
                        ),
                        child: Text(
                          'Resend',
                          style: DDTypography.caption.copyWith(
                            color: DDColors.hunterGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: eventsAsync.when(
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
                                _filterTypes.contains(e.type)) &&
                            (_filterTag == null ||
                                e.tags.contains(_filterTag)) &&
                            _eventMatchesSearch(e))
                        .toList();

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final todayCount = allEvents
                        .where((e) => !e.timestamp.isBefore(today))
                        .length;
                    final motionEvents = allEvents
                        .where((e) => e.type == EventType.motion)
                        .toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    final lastMotion = motionEvents.isNotEmpty
                        ? motionEvents.first.timestamp
                        : null;
                    final clipCount = clipsAsync.valueOrNull?.length;

                    final dashboard = _DashboardCard(
                      device: device,
                      isLanReachable: isLanReachable,
                      todayCount: allEvents.isEmpty ? null : todayCount,
                      clipCount: clipCount,
                      lastMotion: lastMotion,
                    );

                    if (events.isEmpty) {
                      final isSearchOrFilter =
                          _isSearching || hasActiveFilter;
                      return Column(
                        children: [
                          dashboard,
                          Expanded(
                            child: isSearchOrFilter
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.search_off_outlined,
                                            size: 48,
                                            color: DDColors.borderDefault),
                                        const SizedBox(height: DDSpacing.sm),
                                        Text(
                                          'No events matching your search.',
                                          style: DDTypography.bodyM.copyWith(
                                              color: DDColors.textMuted),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : DDEmptyState.events(
                                    action: DDButton.secondary(
                                      label: 'Add your DingDong device',
                                      onPressed: () =>
                                          context.go(Routes.onboardWelcome),
                                      fullWidth: false,
                                    ),
                                  ),
                          ),
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
              ),
            ],
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

/// Device name pill — shows connectivity status with wifi/globe icon.
/// Tappable to open the device switcher sheet.
class _DeviceNamePill extends StatelessWidget {
  final String name;
  final bool isOnline;
  final bool isRemote;

  const _DeviceNamePill({
    required this.name,
    required this.isOnline,
    required this.isRemote,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = (isOnline || isRemote)
        ? DDColors.hunterGreen
        : DDColors.textMuted;
    final statusIcon = isRemote
        ? Icons.public
        : (isOnline ? Icons.wifi : Icons.wifi_off);

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
          PulsingDot(isOnline: isOnline || isRemote),
          const SizedBox(width: 4),
          Icon(statusIcon, size: 12, color: iconColor),
          const SizedBox(width: 4),
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
        1 + sections.fold<int>(0, (acc, s) => acc + 1 + s.value.length);

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
                      if (event.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: event.tags
                              .take(3)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: DDColors.softGreenGray,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: DDTypography.caption.copyWith(
                                        fontSize: 10,
                                        color: DDColors.textMuted,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
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
