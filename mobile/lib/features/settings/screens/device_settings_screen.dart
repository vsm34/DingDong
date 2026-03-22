import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../models/device_model.dart';
import '../../../models/device_settings_model.dart';
import '../../../providers/providers.dart';

/// /settings/device — Device settings.
/// Device status card, Motion section, Notifications section,
/// Clips section, Danger Zone.
class DeviceSettingsScreen extends ConsumerWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final device = ref.watch(deviceProvider);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text('Device Settings', style: DDTypography.h3),
      ),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: DDLoadingIndicator(size: DDLoadingSize.md)),
        error: (_, __) => Center(
          child:
              Text('Could not load settings', style: DDTypography.bodyM),
        ),
        data: (settings) => _SettingsBody(device: device, settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  final DdDevice device;
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
    final isLanReachable = ref.watch(lanReachableProvider);
    final device = ref.watch(deviceProvider);

    return ListView(
      padding: const EdgeInsets.all(DDSpacing.xl),
      children: [
        // Device status card
        DDCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName, style: DDTypography.h3),
                    Text(
                      'v${device.firmwareVersion ?? '—'}',
                      style: DDTypography.caption,
                    ),
                    Text(
                      'Last seen ${device.lastSeenLabel}',
                      style:
                          DDTypography.caption.copyWith(color: DDColors.textMuted),
                    ),
                  ],
                ),
              ),
              isLanReachable
                  ? const DDChip.online()
                  : const DDChip.offline(),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.xl),
        // MOTION
        const _SectionLabel('MOTION'),
        DDCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Motion Detection',
                value: _local.motionEnabled,
                onChanged: (v) =>
                    _save(_local.copyWith(motionEnabled: v)),
              ),
              const Divider(
                height: 0.5,
                thickness: 0.5,
                color: DDColors.borderDefault,
              ),
              _SliderRow(
                label: 'Sensitivity',
                value: _local.mmwaveThreshold.toDouble(),
                min: 0,
                max: 100,
                onChanged: (v) => setState(
                    () => _local = _local.copyWith(mmwaveThreshold: v.round())),
                onChangeEnd: (v) =>
                    _save(_local.copyWith(mmwaveThreshold: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),
        // NOTIFICATIONS
        const _SectionLabel('NOTIFICATIONS'),
        DDCard(
          child: _ToggleRow(
            label: 'Push Notifications',
            value: _local.notifyEnabled,
            onChanged: (v) => _save(_local.copyWith(notifyEnabled: v)),
          ),
        ),
        const SizedBox(height: DDSpacing.lg),
        // CLIPS
        const _SectionLabel('CLIPS'),
        DDCard(
          child: _TapRow(
            label: 'Clip Length',
            trailing: Text(
              '${_local.clipLengthSec}s',
              style: DDTypography.bodyM,
            ),
            onTap: () => _showClipLengthPicker(context),
          ),
        ),
        const SizedBox(height: DDSpacing.xl),
        // DANGER ZONE
        const _SectionLabel('DANGER ZONE'),
        DDButton.destructive(
          label: 'Forget this device',
          onPressed: () => DDConfirmSheet.show(
            context: context,
            title: 'Forget Device',
            message:
                'This will remove the device from your account and reset it to factory defaults.',
            confirmLabel: 'Forget Device',
            isDestructive: true,
            onConfirm: () {
              DDToast.error(context, 'Device removed.');
            },
          ),
        ),
      ],
    );
  }

  void _showClipLengthPicker(BuildContext context) {
    DDBottomSheet.show(
      context: context,
      title: 'Clip Length',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: DeviceSettings.validClipLengths
            .map(
              (sec) => ListTile(
                title: Text('$sec seconds', style: DDTypography.bodyM),
                trailing: sec == _local.clipLengthSec
                    ? const Icon(Icons.check, color: DDColors.hunterGreen)
                    : null,
                onTap: () {
                  _save(_local.copyWith(clipLengthSec: sec));
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DDSpacing.sm),
      child: Text(
        text,
        style: DDTypography.caption.copyWith(
          color: DDColors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md, vertical: DDSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DDTypography.bodyM)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: DDColors.hunterGreen,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md, vertical: DDSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: DDTypography.bodyM)),
              Text('${value.round()}', style: DDTypography.label),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: DDColors.hunterGreen,
              activeTrackColor: DDColors.hunterGreen,
              inactiveTrackColor: DDColors.borderDefault,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  const _TapRow({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.md, vertical: DDSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(label, style: DDTypography.bodyM)),
            trailing,
            const SizedBox(width: DDSpacing.sm),
            const Icon(Icons.chevron_right, size: 18, color: DDColors.textMuted),
          ],
        ),
      ),
    );
  }
}
