import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../providers/providers.dart';

/// /events/heatmap — Activity heatmap showing motion frequency by hour of day.
class ActivityHeatmapScreen extends ConsumerStatefulWidget {
  const ActivityHeatmapScreen({super.key});

  @override
  ConsumerState<ActivityHeatmapScreen> createState() =>
      _ActivityHeatmapScreenState();
}

class _ActivityHeatmapScreenState
    extends ConsumerState<ActivityHeatmapScreen> {
  int _rangeDays = 30;
  bool _isLoading = false;
  List<int> _hourCounts = List.filled(24, 0);
  int _totalEvents = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final device = ref.read(deviceProvider);
    final since = DateTime.now().subtract(Duration(days: _rangeDays));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('deviceId', isEqualTo: device.deviceId)
          .where('type', isEqualTo: 'motion')
          .where('ts', isGreaterThan: Timestamp.fromDate(since))
          .get();

      final counts = List.filled(24, 0);
      for (final doc in snap.docs) {
        final ts = (doc.data()['ts'] as Timestamp).toDate();
        counts[ts.hour]++;
      }
      if (mounted) {
        setState(() {
          _hourCounts = counts;
          _totalEvents = counts.fold(0, (a, b) => a + b);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  String _rangeLabel(int hour) {
    final next = (hour + 1) % 24;
    return '${_hourLabel(hour)}-${_hourLabel(next)}';
  }

  int get _peakHour {
    int peak = 0;
    for (int i = 1; i < 24; i++) {
      if (_hourCounts[i] > _hourCounts[peak]) peak = i;
    }
    return peak;
  }

  Color _barColor(int count) {
    if (count == 0) return const Color(0xFFE8F5E9);
    if (count <= 2) return const Color(0xFF81C784);
    if (count <= 5) return const Color(0xFF4CAF50);
    return const Color(0xFF355E3B);
  }

  @override
  Widget build(BuildContext context) {
    final maxCount =
        _hourCounts.fold(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Activity Heatmap', style: DDTypography.h3),
      ),
      body: Column(
        children: [
          // Date range chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DDSpacing.xl, DDSpacing.md, DDSpacing.xl, 0),
            child: Row(
              children: [7, 30, 90].map((days) {
                final selected = _rangeDays == days;
                return Padding(
                  padding: const EdgeInsets.only(right: DDSpacing.sm),
                  child: GestureDetector(
                    onTap: () {
                      if (_rangeDays != days) {
                        setState(() => _rangeDays = days);
                        _fetchData();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? DDColors.hunterGreen
                            : DDColors.softGreenGray,
                        borderRadius:
                            BorderRadius.circular(DDSpacing.radiusFull),
                        border: Border.all(
                          color: selected
                              ? DDColors.hunterGreen
                              : DDColors.borderDefault,
                        ),
                      ),
                      child: Text(
                        '$days days',
                        style: DDTypography.caption.copyWith(
                          color: selected ? DDColors.white : DDColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: DDSpacing.md),
          // Summary stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Most active',
                            style: DDTypography.caption
                                .copyWith(color: DDColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          _totalEvents > 0
                              ? _rangeLabel(_peakHour)
                              : '—',
                          style: DDTypography.label.copyWith(
                            color: DDColors.hunterGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DDSpacing.sm),
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total events',
                            style: DDTypography.caption
                                .copyWith(color: DDColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '$_totalEvents',
                          style: DDTypography.label.copyWith(
                            color: DDColors.hunterGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DDSpacing.sm),
                Expanded(
                  child: DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily avg',
                            style: DDTypography.caption
                                .copyWith(color: DDColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          _rangeDays > 0
                              ? (_totalEvents / _rangeDays)
                                  .toStringAsFixed(1)
                              : '—',
                          style: DDTypography.label.copyWith(
                            color: DDColors.hunterGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DDSpacing.md),
          const Divider(
              height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
          // Chart
          Expanded(
            child: _isLoading
                ? const Center(
                    child: DDLoadingIndicator(size: DDLoadingSize.md))
                : _totalEvents == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bar_chart_outlined,
                                size: 48, color: DDColors.borderDefault),
                            const SizedBox(height: DDSpacing.sm),
                            Text('No motion events in this period.',
                                style: DDTypography.bodyM
                                    .copyWith(color: DDColors.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DDSpacing.xl, vertical: DDSpacing.md),
                        itemCount: 24,
                        itemBuilder: (context, hour) {
                          final count = _hourCounts[hour];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    _hourLabel(hour),
                                    style: DDTypography.caption.copyWith(
                                      color: DDColors.textMuted,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: DDSpacing.sm),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final fraction = maxCount > 0
                                          ? count / maxCount
                                          : 0.0;
                                      final barW =
                                          constraints.maxWidth * fraction;
                                      return Stack(
                                        children: [
                                          Container(
                                            height: 18,
                                            width: constraints.maxWidth,
                                            decoration: BoxDecoration(
                                              color:
                                                  const Color(0xFFE8F5E9),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          if (count > 0)
                                            Container(
                                              height: 18,
                                              width: barW < 4 ? 4 : barW,
                                              decoration: BoxDecoration(
                                                color: _barColor(count),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: DDSpacing.sm),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    count > 0 ? '$count' : '',
                                    style: DDTypography.caption.copyWith(
                                      color: DDColors.textMuted,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
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
