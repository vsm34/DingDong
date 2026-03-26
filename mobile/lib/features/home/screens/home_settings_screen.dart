import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_list_tile.dart';
import '../../../components/dd_logo.dart';
import '../../../components/dd_toast.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /home/settings — Settings tab.
/// DEVICE section (Add Device, Remove Device), account card, device card, app section.
class HomeSettingsScreen extends ConsumerStatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  ConsumerState<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends ConsumerState<HomeSettingsScreen> {
  Future<void> _removeDevice() async {
    final device = ref.read(deviceProvider);
    final uid = ref.read(authProvider).user!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('deviceMembers')
          .doc('${device.deviceId}_$uid')
          .delete();
      Hive.box('settings').delete('onboarding_skipped');
      ref.invalidate(deviceMembershipProvider);
      if (mounted) {
        DDToast.success(context, 'Device removed');
        context.go(Routes.onboardWelcome);
      }
    } catch (_) {
      // Non-fatal — let the sheet reset its loading state
    }
  }

  void _showRemoveDeviceSheet() {
    var removing = false;
    DDBottomSheet.show<void>(
      context: context,
      title: 'Remove Device',
      child: StatefulBuilder(
        builder: (ctx, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will unpair your DingDong device. You can re-add it at any time.',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            ),
            const SizedBox(height: DDSpacing.lg),
            DDButton.destructive(
              label: 'Remove Device',
              isLoading: removing,
              onPressed: removing
                  ? null
                  : () async {
                      setSS(() => removing = true);
                      await _removeDevice();
                      if (ctx.mounted) setSS(() => removing = false);
                    },
            ),
            const SizedBox(height: DDSpacing.sm),
            DDButton.secondary(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final isLanReachable = ref.watch(lanReachableProvider);
    final membershipAsync = ref.watch(deviceMembershipProvider);
    final hasDevice = membershipAsync.valueOrNull == true;

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
          // DEVICE section
          const _SectionHeader(label: 'DEVICE'),
          DDListTile(
            leading: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF355E3B),
            ),
            title: 'Add Device',
            subtitle: 'Pair a new DingDong device',
            onTap: () => context.push(Routes.onboardWelcome),
            showDivider: hasDevice,
          ),
          if (hasDevice)
            DDListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFDC2626),
              ),
              title: 'Remove Device',
              subtitle: 'Unpair this device from your account',
              onTap: _showRemoveDeviceSheet,
              showDivider: false,
            ),
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
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
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
          // Activity section
          const _SectionHeader(label: 'ACTIVITY'),
          _SettingsRow(
            label: 'Activity Heatmap',
            icon: Icons.bar_chart_outlined,
            onTap: () => context.push(Routes.activityHeatmap),
          ),
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
          // Support section
          const _SectionHeader(label: 'SUPPORT'),
          _SettingsRow(
            label: 'AI Support',
            icon: Icons.support_agent,
            onTap: () => context.push(Routes.supportChat),
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

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DDSpacing.xl, DDSpacing.lg, DDSpacing.xl, DDSpacing.xs),
      child: Text(
        label,
        style: DDTypography.caption.copyWith(
          color: DDColors.textMuted,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
  final IconData? icon;

  const _SettingsRow({required this.label, required this.onTap, this.icon});

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
            if (icon != null) ...[
              Icon(icon, size: 20, color: DDColors.hunterGreen),
              const SizedBox(width: DDSpacing.sm),
            ],
            Expanded(child: Text(label, style: DDTypography.bodyM)),
            const Icon(Icons.chevron_right, size: 20, color: DDColors.textMuted),
          ],
        ),
      ),
    );
  }
}
