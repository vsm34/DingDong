import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../models/event_model.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /events/:eventId — Event detail.
/// Hero banner (doorbell/motion), sensor stats, Play Clip button.
/// Next/previous navigation arrows.
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final eventsAsync = ref.watch(eventsProvider);

    // Build sorted event id list for prev/next
    final allEventIds = eventsAsync.valueOrNull
            ?.map((e) => e.id)
            .toList() ??
        [];
    final currentIndex = allEventIds.indexOf(eventId);
    final prevId =
        currentIndex > 0 ? allEventIds[currentIndex - 1] : null;
    final nextId = currentIndex >= 0 && currentIndex < allEventIds.length - 1
        ? allEventIds[currentIndex + 1]
        : null;

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF355E3B)),
          onPressed: () => context.pop(),
        ),
        title: Text('Event', style: DDTypography.h3),
        actions: [
          if (prevId != null)
            IconButton(
              onPressed: () => context.replace(Routes.eventDetailPath(prevId)),
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Previous',
            ),
          if (nextId != null)
            IconButton(
              onPressed: () => context.replace(Routes.eventDetailPath(nextId)),
              icon: const Icon(Icons.arrow_forward, size: 20),
              tooltip: 'Next',
            ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline, color: DDColors.error),
          ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(
          child: DDLoadingIndicator(size: DDLoadingSize.lg),
        ),
        error: (_, __) => Center(
          child: Text('Error loading event', style: DDTypography.bodyM),
        ),
        data: (event) {
          if (event == null) {
            return Center(
              child: Text('Event not found', style: DDTypography.bodyM),
            );
          }
          return _EventDetailBody(event: event);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    DDConfirmSheet.show(
      context: context,
      title: 'Delete Event',
      message: 'This event will be permanently deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () {
        if (context.canPop()) context.pop();
      },
    );
  }
}

class _EventDetailBody extends ConsumerStatefulWidget {
  final DdEvent event;

  const _EventDetailBody({required this.event});

  @override
  ConsumerState<_EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends ConsumerState<_EventDetailBody> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  late List<String> _tags;
  String? _aiSummary;
  bool _isGeneratingSummary = false;

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.event.tags);
    _aiSummary = widget.event.aiSummary;
  }

  Future<void> _generateSummary() async {
    setState(() => _isGeneratingSummary = true);
    final deviceName = ref.read(deviceProvider).displayName;
    final summary = await ref
        .read(aiServiceProvider)
        .generateEventSummary(widget.event, deviceName);
    if (!mounted) return;
    if (summary != null) {
      setState(() {
        _aiSummary = summary;
        _isGeneratingSummary = false;
      });
    } else {
      setState(() => _isGeneratingSummary = false);
      DDToast.error(context, 'Could not generate summary');
    }
  }

  void _showAddTagSheet(BuildContext context) {
    final ctrl = TextEditingController();
    DDBottomSheet.show<void>(
      context: context,
      title: 'Add Tag',
      child: StatefulBuilder(
        builder: (ctx, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DDTextField(
              label: 'Tag Name',
              hint: 'e.g. delivery, neighbor',
              controller: ctrl,
              maxLength: 20,
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DDSpacing.lg),
            DDButton.primary(
              label: 'Add Tag',
              onPressed: () async {
                final tag = ctrl.text.trim().toLowerCase();
                if (tag.isEmpty) return;
                Navigator.of(ctx).pop();
                await _addTag(tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTag(String tag) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'tags': FieldValue.arrayUnion([tag])});
      setState(() {
        if (!_tags.contains(tag)) _tags.add(tag);
      });
      if (mounted) DDToast.success(context, 'Tag added');
    } catch (_) {
      if (mounted) DDToast.error(context, 'Failed to add tag.');
    }
  }

  Future<void> _removeTag(String tag) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'tags': FieldValue.arrayRemove([tag])});
      setState(() => _tags.remove(tag));
    } catch (_) {
      if (mounted) DDToast.error(context, 'Failed to remove tag.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoorbell = widget.event.type == EventType.doorbell;
    final isLanReachable = ref.watch(lanReachableProvider);
    final stats = widget.event.sensorStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DDSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          isDoorbell
              ? DDCard.doorbell(
                  child: _HeroBannerContent(
                    icon: Icons.doorbell_outlined,
                    iconColor: DDColors.doorbellEventChip,
                    title: 'Doorbell Press',
                    timestamp: widget.event.timestamp,
                  ),
                )
              : DDCard.motion(
                  child: _HeroBannerContent(
                    icon: Icons.directions_run,
                    iconColor: DDColors.motionEventChip,
                    title: 'Motion Detected',
                    timestamp: widget.event.timestamp,
                  ),
                ),
          const SizedBox(height: DDSpacing.lg),
          // AI Summary
          if (_aiSummary != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: Color(0xFF355E3B)),
                const SizedBox(width: DDSpacing.xs),
                Expanded(
                  child: Text(
                    _aiSummary!,
                    style: DDTypography.bodyM.copyWith(
                      color: const Color(0xFF355E3B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            )
          else if (_isGeneratingSummary)
            const Center(
                child: DDLoadingIndicator(size: DDLoadingSize.sm))
          else
            DDButton.secondary(
              label: 'Generate Summary',
              leading: const Icon(Icons.auto_awesome,
                  size: 16, color: DDColors.hunterGreen),
              onPressed: _generateSummary,
            ),
          const SizedBox(height: DDSpacing.lg),
          // Sensor stats
          if (stats != null) ...[
            Text(
              'Sensor Data',
              style: DDTypography.label.copyWith(color: DDColors.textMuted),
            ),
            const SizedBox(height: DDSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motion Sensor (PIR)',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: DDSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              stats.pirTriggered
                                  ? Icons.sensors
                                  : Icons.sensors_off,
                              size: 14,
                              color: stats.pirTriggered
                                  ? DDColors.motionEventChip
                                  : DDColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              stats.pirTriggered
                                  ? 'Body heat detected'
                                  : 'No heat signature',
                              style: DDTypography.bodyM.copyWith(
                                fontWeight: FontWeight.w600,
                                color: stats.pirTriggered
                                    ? DDColors.motionEventChip
                                    : DDColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DDSpacing.md),
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radar (mmWave)',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: DDSpacing.xs),
                        Text(
                          stats.mmwaveDistance != null
                              ? _distanceLabel(stats.mmwaveDistance!)
                              : 'No target',
                          style: DDTypography.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DDSpacing.lg),
          ],
          // Tags
          Text(
            'Tags',
            style: DDTypography.label.copyWith(color: DDColors.textMuted),
          ),
          const SizedBox(height: DDSpacing.sm),
          Wrap(
            spacing: DDSpacing.sm,
            runSpacing: DDSpacing.xs,
            children: [
              ..._tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DDColors.softGreenGray,
                      borderRadius:
                          BorderRadius.circular(DDSpacing.radiusFull),
                      border: Border.all(color: DDColors.borderDefault),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$tag',
                          style: DDTypography.caption.copyWith(
                            color: DDColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeTag(tag),
                          child: const Icon(Icons.close,
                              size: 12, color: DDColors.textMuted),
                        ),
                      ],
                    ),
                  )),
              GestureDetector(
                onTap: () => _showAddTagSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DDColors.hunterGreen.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(DDSpacing.radiusFull),
                    border: Border.all(
                        color: DDColors.hunterGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add,
                          size: 12, color: DDColors.hunterGreen),
                      const SizedBox(width: 3),
                      Text(
                        'Add tag',
                        style: DDTypography.caption.copyWith(
                          color: DDColors.hunterGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DDSpacing.lg),
          // Play Clip
          if (widget.event.clipId != null) ...[
            DDButton.primary(
              label: isLanReachable
                  ? (_isDownloading ? 'Loading clip...' : 'Play Clip')
                  : 'Available on home Wi-Fi',
              onPressed: isLanReachable && !_isDownloading
                  ? () => _playClip(context)
                  : null,
              isLoading: _isDownloading,
            ),
            if (_isDownloading) ...[
              const SizedBox(height: DDSpacing.sm),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(DDSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  minHeight: 4,
                  backgroundColor: DDColors.borderDefault,
                  color: DDColors.hunterGreen,
                ),
              ),
              const SizedBox(height: DDSpacing.xs),
              Text(
                _downloadProgress > 0
                    ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
                    : 'Preparing…',
                style: DDTypography.caption
                    .copyWith(color: DDColors.textMuted),
              ),
            ],
            if (!_isDownloading) ...[
              const SizedBox(height: DDSpacing.sm),
              Text(
                'Clip stored locally on your device.',
                style: DDTypography.caption
                    .copyWith(color: DDColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _distanceLabel(double meters) {
    if (meters < 0.5) return 'Very close (<0.5 m)';
    if (meters < 1.5) return '${meters.toStringAsFixed(1)} m — Near';
    if (meters < 3.0) return '${meters.toStringAsFixed(1)} m — Mid-range';
    return '${meters.toStringAsFixed(1)} m — Far';
  }

  Future<void> _playClip(BuildContext context) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    final router = GoRouter.of(context);
    // Simulate progress for the placeholder implementation
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _downloadProgress = i / 5);
    }
    if (!mounted) return;
    setState(() => _isDownloading = false);
    router.push(Routes.clipPlayerPath(widget.event.clipId!));
  }
}

class _HeroBannerContent extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final DateTime timestamp;

  const _HeroBannerContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(width: DDSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DDTypography.h2),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy · h:mm a').format(timestamp),
                style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
