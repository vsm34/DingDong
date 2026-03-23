import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

/// /debug — Developer-only screen. Not linked from production nav.
/// Monospaced font. Auth state, device state, provider states.
/// "Trigger mock motion event" + "Toggle LAN Reachable" buttons.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final isLanReachable = ref.watch(lanReachableProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final clipsAsync = ref.watch(clipsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final onboarding = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        title: Text('Debug', style: DDTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(DDSpacing.lg),
        children: [
          _DebugSection(
            title: 'AUTH STATE',
            rows: {
              'uid': auth.user?.uid ?? 'null',
              'email': auth.user?.email ?? 'null',
              'displayName': auth.user?.displayName ?? 'null',
              'isAuthenticated': '${auth.isAuthenticated}',
              'isLoading': '${auth.isLoading}',
            },
          ),
          const SizedBox(height: DDSpacing.lg),
          _DebugSection(
            title: 'DEVICE STATE',
            rows: {
              'deviceId': device.deviceId,
              'displayName': device.displayName,
              'lanReachable': '$isLanReachable',
              'isOnline': '${device.isOnline}',
              'lastSeen': device.lastSeenLabel,
              'fwVersion': device.firmwareVersion ?? 'null',
            },
          ),
          const SizedBox(height: DDSpacing.lg),
          _DebugSection(
            title: 'PROVIDERS',
            rows: {
              'events': eventsAsync.when(
                data: (e) => '${e.length} events',
                loading: () => 'loading...',
                error: (e, _) => 'error: $e',
              ),
              'clips': clipsAsync.when(
                data: (c) => '${c.length} clips',
                loading: () => 'loading...',
                error: (e, _) => 'error: $e',
              ),
              'settings': settingsAsync.when(
                data: (s) =>
                    'motion=${s.motionEnabled} notify=${s.notifyEnabled} clip=${s.clipLengthSec}s',
                loading: () => 'loading...',
                error: (e, _) => 'error: $e',
              ),
              'onboarding.step': onboarding.step.name,
              'onboarding.device': onboarding.deviceName ?? 'null',
            },
          ),
          const SizedBox(height: DDSpacing.xl),
          DDButton.primary(
            label: 'Trigger Mock Motion Event',
            onPressed: () {
              ref.invalidate(eventsProvider);
              DDToast.success(context, 'Mock motion event triggered.');
            },
          ),
          const SizedBox(height: DDSpacing.md),
          DDButton.secondary(
            label: isLanReachable
                ? 'Simulate Going Off-LAN'
                : 'Simulate Going On-LAN',
            onPressed: () {
              ref.read(lanReachableProvider.notifier).debugOverride(!isLanReachable);
              DDToast.info(
                context,
                'LAN: ${!isLanReachable ? "reachable" : "unreachable"}',
              );
            },
          ),
          const SizedBox(height: DDSpacing.md),
          DDButton.secondary(
            label: 'Reset Onboarding',
            onPressed: () {
              Hive.box('settings').delete('onboarding_skipped');
              ref.invalidate(deviceMembershipProvider);
              DDToast.info(context, 'Onboarding reset.');
              context.go('/home/events');
            },
          ),
          const SizedBox(height: DDSpacing.xl),
          Center(
            child: Text(
              'Phase 1 — All data is mock',
              style: DDTypography.mono.copyWith(
                  color: DDColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _DebugSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DDTypography.mono.copyWith(
            color: DDColors.hunterGreen,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: DDSpacing.sm),
        Container(
          padding: const EdgeInsets.all(DDSpacing.md),
          decoration: BoxDecoration(
            color: DDColors.softGreenGray,
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
            border: Border.all(color: DDColors.borderDefault, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            e.key,
                            style: DDTypography.mono.copyWith(
                                color: DDColors.textMuted, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: DDTypography.mono.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
