import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../models/clip_model.dart';
import '../../../providers/providers.dart';

/// /clips/:clipId — Clip player.
/// Phase 1: mock player. Phase 2B: better_player integration.
/// Back button, info button, seek bar, play/pause, fullscreen.
class ClipPlayerScreen extends ConsumerStatefulWidget {
  final String clipId;

  const ClipPlayerScreen({super.key, required this.clipId});

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen> {
  DdClip? _clip;
  bool _isPlaying = false;
  double _progress = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClip();
  }

  Future<void> _loadClip() async {
    final clips = await ref.read(clipsProvider.future);
    if (mounted) {
      setState(() {
        _clip = clips.where((c) => c.clipId == widget.clipId).firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video placeholder (Phase 2B: better_player)
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(
                  color: const Color(0xFF111111),
                  child: Center(
                    child: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 72,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Spacer(),
                if (_clip != null) ...[
                  IconButton(
                    onPressed: _isSaving ? null : _saveToGallery,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download,
                            color: Colors.white),
                    tooltip: 'Save to gallery',
                  ),
                  IconButton(
                    onPressed: () => _showMetadata(context),
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + DDSpacing.lg,
            left: DDSpacing.lg,
            right: DDSpacing.lg,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbColor: DDColors.hunterGreen,
                    activeTrackColor: DDColors.hunterGreen,
                    inactiveTrackColor: Colors.white24,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: (v) => setState(() => _progress = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () =>
                          setState(() => _isPlaying = !_isPlaying),
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: DDSpacing.md),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Loading overlay if clip not yet resolved
          if (_clip == null)
            const Center(
              child: DDLoadingIndicator(size: DDLoadingSize.lg),
            ),
        ],
      ),
    );
  }

  Future<void> _saveToGallery() async {
    if (kIsWeb) {
      DDToast.error(context, 'Save to gallery is not available on web.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final bytes =
          await ref.read(deviceApiProvider).downloadClip(widget.clipId);
      await ImageGallerySaver.saveImage(bytes,
          quality: 100,
          name: 'dingdong_${widget.clipId}');
      if (mounted) DDToast.success(context, 'Clip saved to gallery.');
    } catch (_) {
      if (mounted) DDToast.error(context, 'Failed to save clip.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMetadata(BuildContext context) {
    final clip = _clip!;
    DDBottomSheet.show(
      context: context,
      title: 'Clip Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetaRow(
            label: 'Recorded',
            value: DateFormat('MMM d, yyyy h:mm a').format(clip.timestamp),
          ),
          _MetaRow(label: 'Duration', value: clip.durationLabel),
          _MetaRow(label: 'Size', value: clip.sizeLabel),
          _MetaRow(label: 'ID', value: clip.clipId),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DDSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: DDTypography.caption.copyWith(color: DDColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: DDTypography.bodyM),
          ),
        ],
      ),
    );
  }
}
