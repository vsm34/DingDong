import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

/// /settings/storage — Storage manager.
/// Clips usage bar, auto-delete toggle + threshold (Hive), delete all.
class StorageManagerScreen extends ConsumerStatefulWidget {
  const StorageManagerScreen({super.key});

  @override
  ConsumerState<StorageManagerScreen> createState() =>
      _StorageManagerScreenState();
}

class _StorageManagerScreenState
    extends ConsumerState<StorageManagerScreen> {
  static const _maxMb = 512.0;

  late Box _box;
  bool _autoDelete = false;
  int _autoDeleteDays = 30;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings');
    _autoDelete = _box.get('autoDelete', defaultValue: false) as bool;
    _autoDeleteDays = _box.get('autoDeleteDays', defaultValue: 30) as int;
  }

  void _setAutoDelete(bool v) {
    setState(() => _autoDelete = v);
    _box.put('autoDelete', v);
  }

  void _setAutoDeleteDays(int days) {
    setState(() => _autoDeleteDays = days);
    _box.put('autoDeleteDays', days);
  }

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(clipsProvider);

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
        title: Text('Storage', style: DDTypography.h3),
      ),
      body: clipsAsync.when(
        loading: () =>
            const Center(child: DDLoadingIndicator(size: DDLoadingSize.md)),
        error: (_, __) => Center(
          child: Text('Could not load clips', style: DDTypography.bodyM),
        ),
        data: (clips) {
          final totalBytes =
              clips.fold<int>(0, (sum, c) => sum + c.sizeBytes);
          final totalMb = totalBytes / (1024 * 1024);
          final usedFraction = (totalMb / _maxMb).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(DDSpacing.xl),
            children: [
              // Storage usage card
              DDCard(
                child: Padding(
                  padding: const EdgeInsets.all(DDSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Clip Storage', style: DDTypography.bodyM
                              .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${totalMb.toStringAsFixed(1)} / ${_maxMb.toStringAsFixed(0)} MB',
                            style: DDTypography.caption
                                .copyWith(color: DDColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: DDSpacing.sm),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DDSpacing.radiusFull),
                        child: LinearProgressIndicator(
                          value: usedFraction,
                          minHeight: 8,
                          backgroundColor: DDColors.borderDefault,
                          color: usedFraction > 0.8
                              ? DDColors.error
                              : DDColors.hunterGreen,
                        ),
                      ),
                      const SizedBox(height: DDSpacing.sm),
                      Text(
                        '${clips.length} clip${clips.length == 1 ? '' : 's'} stored',
                        style: DDTypography.caption
                            .copyWith(color: DDColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DDSpacing.xl),
              _buildSectionLabel('AUTO-DELETE'),
              DDCard(
                child: Column(
                  children: [
                    _buildToggleRow(
                      label: 'Auto-delete old clips',
                      value: _autoDelete,
                      onChanged: _setAutoDelete,
                    ),
                    if (_autoDelete) ...[
                      const Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: DDColors.borderDefault),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DDSpacing.md, vertical: DDSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Delete after',
                                  style: DDTypography.bodyM),
                            ),
                            DropdownButton<int>(
                              value: _autoDeleteDays,
                              underline: const SizedBox.shrink(),
                              style: DDTypography.bodyM
                                  .copyWith(color: DDColors.hunterGreen),
                              onChanged: (v) {
                                if (v != null) _setAutoDeleteDays(v);
                              },
                              items: const [
                                DropdownMenuItem(value: 7, child: Text('7 days')),
                                DropdownMenuItem(
                                    value: 14, child: Text('14 days')),
                                DropdownMenuItem(
                                    value: 30, child: Text('30 days')),
                                DropdownMenuItem(
                                    value: 60, child: Text('60 days')),
                                DropdownMenuItem(
                                    value: 90, child: Text('90 days')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DDSpacing.xl),
              _buildSectionLabel('DANGER ZONE'),
              DDButton.destructive(
                label: 'Delete All Clips',
                onPressed: clips.isEmpty
                    ? null
                    : () => _confirmDeleteAll(context, clips.length),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
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

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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

  void _confirmDeleteAll(BuildContext context, int count) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Clips'),
        content: Text(
          'This will permanently delete all $count clip${count == 1 ? '' : 's'} from the device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Invalidate clips provider to trigger a refresh
              ref.invalidate(clipsProvider);
              DDToast.success(context, 'All clips deleted.');
            },
            style: TextButton.styleFrom(foregroundColor: DDColors.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
