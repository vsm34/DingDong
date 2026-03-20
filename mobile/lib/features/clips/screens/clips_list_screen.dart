import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_empty_state.dart';
import '../../../components/dd_logo.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../models/clip_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /home/clips — Clips tab.
/// App bar: DDLogo left, device name pill right.
/// LAN gate banner when off home network. Clip list with long-press delete.
class ClipsListScreen extends ConsumerWidget {
  const ClipsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final isLanReachable = ref.watch(lanReachableProvider);
    final clipsAsync = ref.watch(clipsProvider);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: DDSpacing.xl,
        title: const DDLogo.appBar(showWordmark: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: _DeviceNamePill(
              name: device.displayName,
              isOnline: device.isOnline,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isLanReachable) const _LanGateBanner(),
          Expanded(
            child: clipsAsync.when(
              loading: () => ListView(
                children: List.generate(4, (_) => const DDShimmerTile()),
              ),
              error: (_, __) => DDEmptyState.error(
                action: DDButton.secondary(
                  label: 'Retry',
                  onPressed: () => ref.refresh(clipsProvider.future),
                  fullWidth: false,
                ),
              ),
              data: (clips) {
                if (clips.isEmpty) return const DDEmptyState.clips();
                return RefreshIndicator(
                  color: DDColors.hunterGreen,
                  onRefresh: () => ref.refresh(clipsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: DDSpacing.xl),
                    itemCount: clips.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: DDColors.borderDefault,
                      indent: DDSpacing.xl,
                    ),
                    itemBuilder: (context, i) => _ClipTile(
                      clip: clips[i],
                      onTap: () =>
                          context.push(Routes.clipPlayerPath(clips[i].clipId)),
                      onLongPress: isLanReachable
                          ? () => _showDeleteOptions(context, ref, clips[i])
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteOptions(BuildContext context, WidgetRef ref, DdClip clip) {
    DDConfirmSheet.show(
      context: context,
      title: 'Delete Clip',
      message:
          'This clip will be permanently deleted from your device.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () {
        ref.read(deviceApiProvider).deleteClip(clip.clipId);
        unawaited(ref.refresh(clipsProvider.future));
        DDToast.success(context, 'Clip deleted.');
      },
    );
  }
}

class _LanGateBanner extends StatelessWidget {
  const _LanGateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: DDColors.doorbellEventBg,
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.xl,
        vertical: DDSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: DDColors.warning),
          const SizedBox(width: DDSpacing.sm),
          Expanded(
            child: Text(
              'Connect to home Wi-Fi to browse clips.',
              style: DDTypography.caption.copyWith(color: DDColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceNamePill extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _DeviceNamePill({required this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isOnline ? DDColors.online : DDColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: DDTypography.label.copyWith(color: DDColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  final DdClip clip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ClipTile({
    required this.clip,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
                color: DDColors.softGreenGray,
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              child:
                  const Icon(Icons.access_time, color: DDColors.textMuted, size: 22),
            ),
            const SizedBox(width: DDSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, h:mm a').format(clip.timestamp),
                    style: DDTypography.bodyM
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${clip.durationLabel} · ${clip.sizeLabel}',
                    style: DDTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DDColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
