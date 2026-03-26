import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
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
/// LAN gate banner, storage warning, Clip list with bulk selection mode.
class ClipsListScreen extends ConsumerStatefulWidget {
  const ClipsListScreen({super.key});

  @override
  ConsumerState<ClipsListScreen> createState() => _ClipsListScreenState();
}

class _ClipsListScreenState extends ConsumerState<ClipsListScreen> {
  final _selectedIds = <String>{};
  bool _isSelecting = false;

  static const _maxBytes = 4.0 * 1024 * 1024 * 1024; // 4 GB
  static const _warnThreshold = 0.80;

  void _enterSelectMode(String clipId) {
    setState(() {
      _isSelecting = true;
      _selectedIds.add(clipId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String clipId) {
    setState(() {
      if (_selectedIds.contains(clipId)) {
        _selectedIds.remove(clipId);
      } else {
        _selectedIds.add(clipId);
      }
      if (_selectedIds.isEmpty) _isSelecting = false;
    });
  }

  void _deleteSelected(BuildContext context) {
    final ids = Set<String>.from(_selectedIds);
    for (final id in ids) {
      ref.read(deviceApiProvider).deleteClip(id);
    }
    unawaited(ref.refresh(clipsProvider.future));
    _exitSelectMode();
    DDToast.success(context, '${ids.length} clip${ids.length == 1 ? '' : 's'} deleted.');
  }

  @override
  Widget build(BuildContext context) {
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
        title: _isSelecting
            ? Text('${_selectedIds.length} selected',
                style: DDTypography.h3)
            : const DDLogo.appBar(showWordmark: true),
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: [
          if (_isSelecting)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: DDColors.error),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _deleteSelected(context),
              tooltip: 'Delete selected',
            )
          else
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
              error: (_, __) => DDEmptyState.clips(
                action: DDButton.primary(
                  label: 'Add Device',
                  onPressed: () => context.go(Routes.onboardWelcome),
                ),
              ),
              data: (clips) {
                if (clips.isEmpty) {
                  return DDEmptyState.clips(
                    action: DDButton.primary(
                      label: 'Add Device',
                      onPressed: () => context.go(Routes.onboardWelcome),
                    ),
                  );
                }

                // Storage warning
                final totalBytes =
                    clips.fold<int>(0, (s, c) => s + c.sizeBytes);
                final usedFraction = totalBytes / _maxBytes;
                final showWarning = usedFraction >= _warnThreshold;

                return RefreshIndicator(
                  color: DDColors.hunterGreen,
                  onRefresh: () => ref.refresh(clipsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: DDSpacing.xl),
                    itemCount: clips.length + (showWarning ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showWarning && i == 0) {
                        return _StorageWarningBanner(
                            usedFraction: usedFraction);
                      }
                      final clip = clips[showWarning ? i - 1 : i];
                      return Column(
                        children: [
                          _ClipTile(
                            clip: clip,
                            isSelected: _selectedIds.contains(clip.clipId),
                            isSelecting: _isSelecting,
                            onTap: _isSelecting
                                ? () => _toggleSelect(clip.clipId)
                                : () => context.push(
                                    Routes.clipPlayerPath(clip.clipId)),
                            onLongPress: () =>
                                _enterSelectMode(clip.clipId),
                          ),
                          const Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: DDColors.borderDefault,
                            indent: DDSpacing.xl,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageWarningBanner extends StatelessWidget {
  final double usedFraction;

  const _StorageWarningBanner({required this.usedFraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: DDColors.amber.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.xl,
        vertical: DDSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: DDColors.warning),
          const SizedBox(width: DDSpacing.sm),
          Expanded(
            child: Text(
              'Storage almost full — ${(usedFraction * 100).toStringAsFixed(0)}% used. '
              'Consider deleting old clips.',
              style: DDTypography.caption.copyWith(color: DDColors.warning),
            ),
          ),
        ],
      ),
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
  final bool isSelected;
  final bool isSelecting;

  const _ClipTile({
    required this.clip,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: isSelected
            ? DDColors.hunterGreen.withValues(alpha: 0.08)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.xl,
          vertical: DDSpacing.md,
        ),
        child: Row(
          children: [
            if (isSelecting)
              Padding(
                padding: const EdgeInsets.only(right: DDSpacing.sm),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? DDColors.hunterGreen
                      : DDColors.textMuted,
                  size: 22,
                ),
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DDColors.softGreenGray,
                borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
              ),
              child: const Icon(Icons.access_time,
                  color: DDColors.textMuted, size: 22),
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
            if (!isSelecting)
              const Icon(Icons.chevron_right,
                  color: DDColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
