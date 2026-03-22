import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/providers.dart';

/// Home screen shell — StatefulShellRoute wrapper with bottom nav.
/// Tabs: Events, Clips, Live, Settings.
/// Dark green nav bar (#1A2E1A) with amber selected, 1px top border.
/// Triggers a LAN reachability check whenever the app comes to foreground.
class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _navBg = Color(0xFF1A2E1A);
  static const _navSelected = Color(0xFFF59E0B);
  static const _navUnselected = Color(0x99FFFFFF); // white 60%
  static const _navBorder = Color(0xFF2A4D2F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(lanReachableProvider.notifier).checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final todayCount = _todayCount(eventsAsync.valueOrNull);

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: _BadgedIcon(
          icon: Icons.notifications_none_outlined,
          count: todayCount,
          selected: false,
        ),
        selectedIcon: _BadgedIcon(
          icon: Icons.notifications,
          count: todayCount,
          selected: true,
        ),
        label: 'Events',
      ),
      const NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: 'Clips',
      ),
      const NavigationDestination(
        icon: Icon(Icons.videocam_outlined),
        selectedIcon: Icon(Icons.videocam),
        label: 'Live',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1px top border
          Container(height: 1, color: _navBorder),
          Theme(
            data: Theme.of(context).copyWith(
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: _navBg,
                indicatorColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected ? _navSelected : _navUnselected,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? _navSelected : _navUnselected,
                    size: 24,
                  );
                }),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
            ),
            child: NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: (index) {
                widget.navigationShell.goBranch(
                  index,
                  initialLocation:
                      index == widget.navigationShell.currentIndex,
                );
              },
              destinations: destinations,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ],
      ),
    );
  }

  static int _todayCount(List<dynamic>? events) {
    if (events == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((e) {
      // DdEvent has a .timestamp field
      final ts = (e as dynamic).timestamp as DateTime;
      return !ts.isBefore(today);
    }).length;
  }
}

/// Bell icon with an optional red badge showing today's event count.
class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool selected;

  const _BadgedIcon({
    required this.icon,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFFF59E0B)
        : const Color(0x99FFFFFF);

    if (count == 0) return Icon(icon, color: color, size: 24);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 24),
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
