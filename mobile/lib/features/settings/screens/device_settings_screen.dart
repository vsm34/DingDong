import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_list_tile.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../models/device_settings_model.dart';
import '../../../providers/providers.dart';

class DeviceSettingsScreen extends ConsumerWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Settings')),
      backgroundColor: DDColors.surface,
      body: settingsAsync.when(
        loading: () => const DDLoadingIndicator(centerInScreen: true),
        error: (_, __) => const Center(child: Text('Failed to load settings')),
        data: (settings) => _SettingsBody(device: device, settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  final dynamic device;
  final DeviceSettings settings;

  const _SettingsBody({required this.device, required this.settings});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late DeviceSettings _local;

  @override
  void initState() {
    super.initState();
    _local = widget.settings;
  }

  Future<void> _save(DeviceSettings updated) async {
    setState(() => _local = updated);
    try {
      await ref.read(settingsProvider.notifier).applyUpdate(updated);
      if (mounted) DDToast.success(context, 'Settings saved');
    } catch (_) {
      if (mounted) DDToast.error(context, 'Failed to save settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return ListView(
      padding: const EdgeInsets.all(DDSpacing.pagePadding),
      children: [
        // Device info card
        DDCard(
          backgroundColor: DDColors.navyPrimary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(device.displayName,
                      style: DDTypography.h2
                          .copyWith(color: DDColors.white)),
                  device.isOnline
                      ? const DDChip.online()
                      : const DDChip.offline(),
                ],
              ),
              const SizedBox(height: DDSpacing.xs),
              Text(
                'Last seen: ${device.lastSeenLabel}',
                style: DDTypography.bodySm
                    .copyWith(color: DDColors.textOnDarkSecondary),
              ),
              const SizedBox(height: DDSpacing.xs),
              Text(
                'Firmware: ${device.firmwareVersion ?? "Unknown"}',
                style: DDTypography.caption
                    .copyWith(color: DDColors.textOnDarkSecondary),
              ),
              Text(
                'ID: ${device.deviceId}',
                style: DDTypography.caption
                    .copyWith(color: DDColors.textOnDarkSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),

        // Motion & Notifications
        _SectionHeader('Detection & Alerts'),
        DDCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DDSettingsTile(
                leading: const Icon(Icons.sensors, size: 20,
                    color: DDColors.navyPrimary),
                title: 'Motion Detection',
                description:
                    'Enable PIR + mmWave dual-sensor validation',
                trailing: Switch(
                  value: _local.motionEnabled,
                  onChanged: (v) =>
                      _save(_local.copyWith(motionEnabled: v)),
                ),
              ),
              const Divider(height: 1, indent: DDSpacing.md),
              DDSettingsTile(
                leading: const Icon(Icons.notifications_outlined,
                    size: 20, color: DDColors.navyPrimary),
                title: 'Push Notifications',
                description: 'Receive alerts for motion and doorbell',
                trailing: Switch(
                  value: _local.notifyEnabled,
                  onChanged: (v) =>
                      _save(_local.copyWith(notifyEnabled: v)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),

        // mmWave threshold
        _SectionHeader('Sensitivity'),
        DDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radar, size: 20,
                          color: DDColors.navyPrimary),
                      const SizedBox(width: DDSpacing.sm),
                      Text('mmWave Threshold',
                          style: DDTypography.body.copyWith(
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Text('${_local.mmwaveThreshold}',
                      style: DDTypography.labelLg
                          .copyWith(color: DDColors.electricBlue)),
                ],
              ),
              const SizedBox(height: DDSpacing.xs),
              Text(
                'Higher value = less sensitive to distance',
                style: DDTypography.caption,
              ),
              Slider(
                value: _local.mmwaveThreshold.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_local.mmwaveThreshold}',
                onChanged: (v) =>
                    setState(() => _local = _local.copyWith(
                        mmwaveThreshold: v.round())),
                onChangeEnd: (v) =>
                    _save(_local.copyWith(mmwaveThreshold: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),

        // Clip length
        _SectionHeader('Recording'),
        DDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20,
                      color: DDColors.navyPrimary),
                  const SizedBox(width: DDSpacing.sm),
                  Text('Clip Length',
                      style: DDTypography.body.copyWith(
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: DDSpacing.md),
              Wrap(
                spacing: DDSpacing.sm,
                children: DeviceSettings.validClipLengths.map((sec) {
                  final selected = _local.clipLengthSec == sec;
                  return ChoiceChip(
                    label: Text('${sec}s'),
                    selected: selected,
                    onSelected: (_) =>
                        _save(_local.copyWith(clipLengthSec: sec)),
                    selectedColor: DDColors.navyPrimary,
                    labelStyle: DDTypography.label.copyWith(
                        color: selected
                            ? DDColors.white
                            : DDColors.textPrimary),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
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
