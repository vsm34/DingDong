import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_list_tile.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// Home settings tab — device overview + quick links
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: DDColors.surface,
      body: ListView(
        padding: const EdgeInsets.all(DDSpacing.pagePadding),
        children: [
          // User summary
          DDCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: DDColors.electricBlue,
                  child: Text(
                    (user?.displayName ?? 'U')[0].toUpperCase(),
                    style:
                        DDTypography.h3.copyWith(color: DDColors.white),
                  ),
                ),
                const SizedBox(width: DDSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? '—',
                          style: DDTypography.labelLg),
                      Text(user?.email ?? '—',
                          style: DDTypography.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: DDColors.textDisabled),
              ],
            ),
          ),
          const SizedBox(height: DDSpacing.lg),
          _SectionHeader('Device'),
          DDCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DDSettingsTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: device.isOnline
                              ? DDColors.online
                              : DDColors.offline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  title: device.displayName,
                  description: device.isOnline
                      ? 'Online · FW ${device.firmwareVersion ?? "—"}'
                      : 'Offline · ${device.lastSeenLabel}',
                  onTap: () => context.push(Routes.deviceSettings),
                ),
                const Divider(height: 1, indent: DDSpacing.md),
                DDSettingsTile(
                  leading: const Icon(Icons.tune, size: 20,
                      color: DDColors.navyPrimary),
                  title: 'Device Settings',
                  description: 'Motion, alerts, clip length',
                  onTap: () => context.push(Routes.deviceSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: DDSpacing.lg),
          _SectionHeader('Account'),
          DDCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DDSettingsTile(
                  leading: const Icon(Icons.person_outline, size: 20,
                      color: DDColors.navyPrimary),
                  title: 'Account Settings',
                  description: 'Profile and sign out',
                  onTap: () => context.push(Routes.accountSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: DDSpacing.lg),
          _SectionHeader('Developer'),
          DDCard(
            padding: EdgeInsets.zero,
            child: DDSettingsTile(
              leading: const Icon(Icons.bug_report_outlined, size: 20,
                  color: DDColors.navyPrimary),
              title: 'Debug Screen',
              description: 'Provider states and mock data',
              onTap: () => context.push(Routes.debug),
            ),
          ),
          const SizedBox(height: DDSpacing.lg),
          Center(
            child: Text(
              'DingDong v1.0.0 · Phase 1 (Mock)',
              style: DDTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: DDSpacing.xs, bottom: DDSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: DDTypography.captionBold.copyWith(
          color: DDColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
