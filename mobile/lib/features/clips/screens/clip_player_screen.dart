import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../models/clip_model.dart';
import '../../../providers/providers.dart';

class ClipPlayerScreen extends ConsumerStatefulWidget {
  final String clipId;

  const ClipPlayerScreen({super.key, required this.clipId});

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isPlaying = false;
  bool _downloadComplete = false;
  DdClip? _clip;

  @override
  void initState() {
    super.initState();
    _loadClipInfo();
  }

  Future<void> _loadClipInfo() async {
    final clips = await ref.read(clipsProvider.future);
    if (mounted) {
      setState(() {
        try {
          _clip = clips.firstWhere((c) => c.clipId == widget.clipId);
        } catch (_) {}
      });
    }
  }

  Future<void> _downloadAndPlay() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    // Simulate progressive download
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _downloadProgress = i / 10);
    }

    setState(() {
      _isDownloading = false;
      _downloadComplete = true;
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: DDColors.white,
        title: Text(
          _clip != null
              ? DateFormat('MMM d, h:mm a').format(_clip!.timestamp)
              : widget.clipId,
          style: DDTypography.body.copyWith(color: DDColors.white),
        ),
      ),
      body: Column(
        children: [
          // Video area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildVideoArea(),
            ),
          ),
          // Controls area
          Expanded(
            child: Container(
              color: DDColors.surface,
              padding: const EdgeInsets.all(DDSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_clip != null) ...[
                    DDCard(
                      child: Column(
                        children: [
                          _InfoRow(
                              label: 'Duration',
                              value: _clip!.durationLabel),
                          const Divider(height: 1),
                          _InfoRow(label: 'Size', value: _clip!.sizeLabel),
                          const Divider(height: 1),
                          _InfoRow(
                            label: 'Recorded',
                            value: DateFormat('MMM d, yyyy h:mm a')
                                .format(_clip!.timestamp),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DDSpacing.lg),
                  ],
                  if (!_downloadComplete && !_isDownloading)
                    DDButton.primary(
                      label: 'Download & Play',
                      onPressed: _downloadAndPlay,
                      leading: const Icon(Icons.download_outlined,
                          color: DDColors.white, size: 20),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_isDownloading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 4,
                color: DDColors.electricBlue,
                backgroundColor: DDColors.white.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: DDSpacing.md),
            Text(
              '${(_downloadProgress * 100).toInt()}%',
              style:
                  DDTypography.h3.copyWith(color: DDColors.white),
            ),
            const SizedBox(height: DDSpacing.xs),
            Text(
              'Downloading clip…',
              style:
                  DDTypography.body.copyWith(color: DDColors.textOnDarkSecondary),
            ),
          ],
        ),
      );
    }

    if (_downloadComplete) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: DDColors.navyDark,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 64,
                    color: DDColors.white.withValues(alpha: 0.9),
                  ),
                  if (_isPlaying) ...[
                    const SizedBox(height: DDSpacing.sm),
                    Text(
                      'Mock playback (Phase 1)',
                      style: DDTypography.caption
                          .copyWith(color: DDColors.textOnDarkSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isPlaying = !_isPlaying),
              behavior: HitTestBehavior.translucent,
            ),
          ),
        ],
      );
    }

    // Initial state
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined,
              size: 48, color: DDColors.textOnDarkSecondary),
          const SizedBox(height: DDSpacing.sm),
          Text(
            'Tap Download & Play to watch',
            style: DDTypography.body
                .copyWith(color: DDColors.textOnDarkSecondary),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md, vertical: DDSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: DDTypography.body
                  .copyWith(color: DDColors.textSecondary)),
          Text(value, style: DDTypography.body),
        ],
      ),
    );
  }
}
