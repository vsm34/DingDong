import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_chip.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../models/device_model.dart';
import '../../../models/device_settings_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

const _kLatestFwVersion = '1.0.0';

/// /settings/device — Device settings.
/// Device status card, Motion, Notifications, Clips, Quiet Hours, Storage, Danger Zone.
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
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
    final qhAsync = ref.watch(quietHoursProvider);
    final qh = qhAsync.valueOrNull ?? const QuietHoursState();
    final clipCount = ref.watch(clipsProvider).valueOrNull?.length ?? 0;

    final signalStrength = ref.watch(signalStrengthProvider);
    final msAsync = ref.watch(motionScheduleProvider);
    final ms = msAsync.valueOrNull ?? const MotionScheduleState();
    final hasUpdate = device.firmwareVersion != null &&
        device.firmwareVersion != _kLatestFwVersion;

    return ListView(
      padding: const EdgeInsets.all(DDSpacing.xl),
      children: [
        // Device status card
        DDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(device.displayName, style: DDTypography.h3),
                            const SizedBox(width: DDSpacing.sm),
                            GestureDetector(
                              onTap: () => _renameDevice(context),
                              child: const Icon(Icons.edit_outlined,
                                  size: 16, color: DDColors.textMuted),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'v${device.firmwareVersion ?? '—'}',
                              style: DDTypography.caption,
                            ),
                            if (hasUpdate) ...[
                              const SizedBox(width: DDSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: DDColors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                      DDSpacing.radiusFull),
                                ),
                                child: Text(
                                  'Update available',
                                  style: DDTypography.caption.copyWith(
                                    color: DDColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Last seen ${device.lastSeenLabel}',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        if (signalStrength != null) ...[
                          Text(
                            'Signal: ${_signalLabel(signalStrength)} ($signalStrength dBm)',
                            style: DDTypography.caption
                                .copyWith(color: DDColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  isLanReachable
                      ? const DDChip.online()
                      : const DDChip.offline(),
                ],
              ),
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
        // MOTION SCHEDULE
        const _SectionLabel('MOTION SCHEDULE'),
        DDCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Scheduled Detection',
                value: ms.enabled,
                onChanged: (v) => ref
                    .read(motionScheduleProvider.notifier)
                    .save(ms.copyWith(enabled: v)),
              ),
              if (ms.enabled) ...[
                const Divider(
                    height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
                _TapRow(
                  label: 'Active from',
                  trailing: Text(ms.start.format(context),
                      style: DDTypography.bodyM),
                  onTap: () => _pickScheduleTime(context, ms, isStart: true),
                ),
                const Divider(
                    height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
                _TapRow(
                  label: 'Active until',
                  trailing: Text(ms.end.format(context),
                      style: DDTypography.bodyM),
                  onTap: () => _pickScheduleTime(context, ms, isStart: false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),
        // NOTIFICATIONS
        const _SectionLabel('NOTIFICATIONS'),
        DDCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Push Notifications',
                value: _local.notifyEnabled,
                onChanged: (v) => _save(_local.copyWith(notifyEnabled: v)),
              ),
              const Divider(
                  height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
              _TapRow(
                label: 'Test Notification',
                trailing: const Icon(Icons.send_outlined,
                    size: 18, color: DDColors.textMuted),
                onTap: () => _sendTestNotification(context),
              ),
            ],
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
        const SizedBox(height: DDSpacing.lg),
        // QUIET HOURS
        const _SectionLabel('QUIET HOURS'),
        DDCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Enable Quiet Hours',
                value: qh.enabled,
                onChanged: (v) => ref
                    .read(quietHoursProvider.notifier)
                    .save(qh.copyWith(enabled: v)),
              ),
              if (qh.enabled) ...[
                const Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: DDColors.borderDefault,
                ),
                _TapRow(
                  label: 'Quiet from',
                  trailing: Text(
                    qh.start.format(context),
                    style: DDTypography.bodyM,
                  ),
                  onTap: () => _pickTime(context, qh, isStart: true),
                ),
                const Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: DDColors.borderDefault,
                ),
                _TapRow(
                  label: 'Quiet until',
                  trailing: Text(
                    qh.end.format(context),
                    style: DDTypography.bodyM,
                  ),
                  onTap: () => _pickTime(context, qh, isStart: false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DDSpacing.lg),
        // STORAGE
        const _SectionLabel('STORAGE'),
        DDCard(
          child: _TapRow(
            label: 'Manage Storage',
            trailing: Text(
              '$clipCount clips',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            ),
            onTap: () => context.push(Routes.storageManager),
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

  static String _signalLabel(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -70) return 'Good';
    if (rssi >= -80) return 'Fair';
    return 'Poor';
  }

  void _renameDevice(BuildContext context) {
    final ctrl =
        TextEditingController(text: ref.read(deviceProvider).displayName);
    DDBottomSheet.show(
      context: context,
      title: 'Rename Device',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DDTextField(
            label: 'Device Name',
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: DDSpacing.lg),
          DDButton.primary(
            label: 'Save',
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              final device = ref.read(deviceProvider);
              ref.read(deviceProvider.notifier).state =
                  device.copyWith(displayName: name);
              Navigator.of(context).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('devices')
                    .doc(device.deviceId)
                    .update({'displayName': name});
              } catch (_) {
                // Non-fatal
              }
              if (context.mounted) DDToast.success(context, 'Device renamed.');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    final device = ref.read(deviceProvider);
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        if (context.mounted) DDToast.error(context, 'Not signed in.');
        return;
      }
      final dio = Dio();
      await dio.post(
        'https://us-central1-dingdong-596c2.cloudfunctions.net/testNotify',
        data: {'deviceId': device.deviceId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (context.mounted) DDToast.success(context, 'Test notification sent!');
    } catch (_) {
      if (context.mounted) DDToast.error(context, 'Failed to send test notification.');
    }
  }

  Future<void> _pickScheduleTime(
      BuildContext context, MotionScheduleState ms,
      {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? ms.start : ms.end,
    );
    if (picked != null) {
      ref.read(motionScheduleProvider.notifier).save(
            ms.copyWith(
              start: isStart ? picked : ms.start,
              end: isStart ? ms.end : picked,
            ),
          );
    }
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

  Future<void> _pickTime(
      BuildContext context, QuietHoursState qh, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? qh.start : qh.end,
    );
    if (picked != null) {
      ref.read(quietHoursProvider.notifier).save(
            qh.copyWith(
              start: isStart ? picked : qh.start,
              end: isStart ? qh.end : picked,
            ),
          );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DDSpacing.sm),
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: DDColors.hunterGreen, width: 3),
          ),
        ),
        child: Text(
          text,
          style: DDTypography.caption.copyWith(
            color: DDColors.hunterGreen,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
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

  static String _sensitivityLabel(double value, double min, double max) {
    final pct = (value - min) / (max - min);
    if (pct < 0.34) return 'Low';
    if (pct < 0.67) return 'Medium';
    return 'High';
  }

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
              Text(
                _sensitivityLabel(value, min, max),
                style: DDTypography.label.copyWith(
                  color: DDColors.hunterGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: DDTypography.caption
                      .copyWith(color: DDColors.textMuted, fontSize: 10)),
              Text('Medium',
                  style: DDTypography.caption
                      .copyWith(color: DDColors.textMuted, fontSize: 10)),
              Text('High',
                  style: DDTypography.caption
                      .copyWith(color: DDColors.textMuted, fontSize: 10)),
            ],
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
