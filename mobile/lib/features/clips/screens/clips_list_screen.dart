import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_empty_state.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_toast.dart';
import '../../../models/clip_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

class ClipsListScreen extends ConsumerWidget {
  const ClipsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lanReachable = ref.watch(lanReachableProvider);
    final clipsAsync = ref.watch(clipsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clips')),
      backgroundColor: DDColors.surface,
      body: !lanReachable
          ? DDEmptyState.offline(
              message: 'Connect to your home Wi-Fi to access clips.',
              action: TextButton(
                onPressed: () {},
                child: const Text('Troubleshoot'),
              ),
            )
          : RefreshIndicator(
              color: DDColors.electricBlue,
              onRefresh: () => ref.refresh(clipsProvider.future),
              child: clipsAsync.when(
                loading: () => ListView(
                    children: List.generate(4, (_) => const DDShimmerTile())),
                error: (_, __) => DDEmptyState.error(
                  message: 'Failed to load clips.',
                  action: TextButton(
                    onPressed: () => ref.refresh(clipsProvider.future),
                    child: const Text('Retry'),
                  ),
                ),
                data: (clips) {
                  if (clips.isEmpty) return const DDEmptyState.clips();
                  return ListView(
                    padding: const EdgeInsets.only(
                        top: DDSpacing.sm, bottom: DDSpacing.xl),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DDSpacing.md,
                          vertical: DDSpacing.xs,
                        ),
                        child: Text(
                          '${clips.length} clips on device',
                          style: DDTypography.caption,
                        ),
                      ),
                      ...clips.map((c) => _ClipTile(clip: c)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _ClipTile extends ConsumerWidget {
  final DdClip clip;

  const _ClipTile({required this.clip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md, vertical: DDSpacing.xs),
      child: DDCard(
        onTap: () => context.push(Routes.clipPlayerPath(clip.clipId)),
        padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.md, vertical: DDSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DDColors.navyPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              child: const Icon(Icons.play_circle_outline,
                  color: DDColors.navyPrimary, size: 22),
            ),
            const SizedBox(width: DDSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, h:mm a').format(clip.timestamp),
                    style: DDTypography.body,
                  ),
                  const SizedBox(height: DDSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: DDColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(clip.durationLabel,
                          style: DDTypography.caption),
                      const SizedBox(width: DDSpacing.sm),
                      const Icon(Icons.storage_outlined,
                          size: 12, color: DDColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(clip.sizeLabel, style: DDTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert,
                  color: DDColors.textSecondary, size: 20),
              onPressed: () => _showOptions(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    DDBottomSheet.show(
      context: context,
      title: 'Clip Options',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_outline,
                color: DDColors.navyPrimary),
            title: const Text('Play Clip'),
            onTap: () {
              Navigator.pop(context);
              context.push(Routes.clipPlayerPath(clip.clipId));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: DDColors.error),
            title: Text('Delete',
                style: DDTypography.body.copyWith(color: DDColors.error)),
            onTap: () {
              Navigator.pop(context);
              DDConfirmSheet.show(
                context: context,
                title: 'Delete Clip',
                message: 'This clip will be permanently deleted from the device SD card.',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                isDestructive: true,
                onConfirm: () {
                  ref.read(deviceApiProvider).deleteClip(clip.clipId);
                  unawaited(ref.refresh(clipsProvider.future));
                  DDToast.success(context, 'Clip deleted');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
