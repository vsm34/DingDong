import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../providers/providers.dart';

/// /debug — Developer screen: shows all provider states
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final clipsAsync = ref.watch(clipsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final lanReachable = ref.watch(lanReachableProvider);
    final onboarding = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      backgroundColor: DDColors.surface,
      body: ListView(
        padding: const EdgeInsets.all(DDSpacing.pagePadding),
        children: [
          _DebugCard(
            title: 'Auth State',
            rows: {
              'isAuthenticated': '${auth.isAuthenticated}',
              'uid': auth.user?.uid ?? 'null',
              'email': auth.user?.email ?? 'null',
              'displayName': auth.user?.displayName ?? 'null',
              'isLoading': '${auth.isLoading}',
            },
          ),
          const SizedBox(height: DDSpacing.md),
          _DebugCard(
            title: 'Device',
            rows: {
              'deviceId': device.deviceId,
              'displayName': device.displayName,
              'isOnline': '${device.isOnline}',
              'lastSeen': device.lastSeenLabel,
              'firmwareVersion': device.firmwareVersion ?? 'null',
              'motionEnabled': '${device.motionEnabled}',
              'notifyEnabled': '${device.notifyEnabled}',
            },
          ),
          const SizedBox(height: DDSpacing.md),
          _DebugCard(
            title: 'Events Provider',
            rows: {
              'state': eventsAsync.when(
                loading: () => 'loading',
                error: (e, _) => 'error: $e',
                data: (d) => '${d.length} events',
              ),
            },
          ),
          const SizedBox(height: DDSpacing.md),
          _DebugCard(
            title: 'Clips Provider',
            rows: {
              'state': clipsAsync.when(
                loading: () => 'loading',
                error: (e, _) => 'error: $e',
                data: (d) => '${d.length} clips',
              ),
            },
          ),
          const SizedBox(height: DDSpacing.md),
          _DebugCard(
            title: 'Device Settings',
            rows: {
              'state': settingsAsync.when(
                loading: () => 'loading',
                error: (e, _) => 'error: $e',
                data: (s) => 'motion=${s.motionEnabled}, '
                    'notify=${s.notifyEnabled}, '
                    'mmwave=${s.mmwaveThreshold}, '
                    'clip=${s.clipLengthSec}s',
              ),
            },
          ),
          const SizedBox(height: DDSpacing.md),
          _DebugCard(
            title: 'Network & Onboarding',
            rows: {
              'lanReachable': '$lanReachable',
              'onboarding.step': onboarding.step.name,
              'onboarding.isLoading': '${onboarding.isLoading}',
              'onboarding.deviceName': onboarding.deviceName ?? 'null',
            },
          ),
          const SizedBox(height: DDSpacing.xl),
          Center(
            child: Text(
              'Phase 1 — All data is mock\nNo Firebase or network calls',
              style: DDTypography.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugCard extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _DebugCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return DDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: DDTypography.labelLg
                  .copyWith(color: DDColors.navyPrimary)),
          const SizedBox(height: DDSpacing.sm),
          const Divider(height: 1),
          ...rows.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: DDSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(e.key,
                          style: DDTypography.caption.copyWith(
                              color: DDColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: DDTypography.caption.copyWith(
                            color: DDColors.textPrimary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
