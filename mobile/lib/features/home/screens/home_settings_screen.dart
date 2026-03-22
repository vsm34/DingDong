import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_logo.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /home/settings — Settings tab.
/// Account card (avatar, name, email, arrow). Device card (name, chip, fw, link).
/// App section: About, Help, version.
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final isLanReachable = ref.watch(lanReachableProvider);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: DDSpacing.xl,
        title: const DDLogo.appBar(showWordmark: true),
      ),
      body: ListView(
        children: [
          // Account card
          _SettingsCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: DDColors.hunterGreen,
                  child: Text(
                    _initials(auth.user?.displayName ?? '?'),
                    style: DDTypography.h3.copyWith(color: DDColors.white),
                  ),
                ),
                const SizedBox(width: DDSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user?.displayName ?? 'User',
                        style: DDTypography.h3,
                      ),
                      Text(
                        auth.user?.email ?? '',
                        style: DDTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.accountSettings),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: DDColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
          // Device card
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(device.displayName, style: DDTypography.h3),
                    ),
                    isLanReachable
                        ? const DDChip.online()
                        : const DDChip.offline(),
                  ],
                ),
                const SizedBox(height: DDSpacing.xs),
                Text(
                  'v${device.firmwareVersion ?? '—'}',
                  style: DDTypography.caption,
                ),
                Text(
                  'Last seen ${device.lastSeenLabel}',
                  style: DDTypography.caption,
                ),
                const SizedBox(height: DDSpacing.md),
                GestureDetector(
                  onTap: () => context.push(Routes.deviceSettings),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Device Settings',
                        style: DDTypography.bodyM.copyWith(
                          color: DDColors.hunterGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: DDColors.hunterGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
          // App section
          _SettingsRow(label: 'About', onTap: () {}),
          _SettingsRow(label: 'Help', onTap: () {}),
          _SettingsRow(
            label: 'Debug Screen',
            onTap: () => context.push(Routes.debug),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DDSpacing.xl, DDSpacing.sm, DDSpacing.xl, DDSpacing.xl),
            child: Text('Version 1.0.0', style: DDTypography.caption),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DDSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(DDSpacing.lg),
        decoration: BoxDecoration(
          color: DDColors.softGreenGray,
          borderRadius: BorderRadius.circular(DDSpacing.radiusLg),
        ),
        child: child,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.xl,
          vertical: DDSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: DDTypography.bodyM)),
            const Icon(Icons.chevron_right, size: 20, color: DDColors.textMuted),
          ],
        ),
      ),
    );
  }
}
