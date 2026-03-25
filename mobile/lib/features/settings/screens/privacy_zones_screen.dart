import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

/// /settings/privacy-zones — Draw and manage camera privacy zones.
class PrivacyZonesScreen extends ConsumerStatefulWidget {
  const PrivacyZonesScreen({super.key});

  @override
  ConsumerState<PrivacyZonesScreen> createState() => _PrivacyZonesScreenState();
}

class _PrivacyZonesScreenState extends ConsumerState<PrivacyZonesScreen> {
  List<Map<String, double>> _zones = [];
  bool _isSaving = false;

  // Drawing state
  Offset? _dragStart;
  Rect? _liveRect;

  static const _maxZones = 4;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings != null) {
      _zones = List.of(settings.privacyZones);
    }
  }

  void _onPanStart(DragStartDetails details, Size frameSize) {
    final dx = details.localPosition.dx / frameSize.width;
    final dy = details.localPosition.dy / frameSize.height;
    setState(() {
      _dragStart = Offset(dx.clamp(0, 1), dy.clamp(0, 1));
      _liveRect = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size frameSize) {
    if (_dragStart == null) return;
    final dx = details.localPosition.dx / frameSize.width;
    final dy = details.localPosition.dy / frameSize.height;
    final end = Offset(dx.clamp(0, 1), dy.clamp(0, 1));
    setState(() {
      _liveRect = Rect.fromPoints(_dragStart!, end);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final rect = _liveRect;
    if (rect == null || _dragStart == null) return;

    // Ignore tiny zones < 10% in either dimension
    if (rect.width < 0.1 && rect.height < 0.1) {
      setState(() {
        _dragStart = null;
        _liveRect = null;
      });
      return;
    }

    if (_zones.length >= _maxZones) {
      DDToast.error(context, 'Maximum 4 privacy zones allowed');
      setState(() {
        _dragStart = null;
        _liveRect = null;
      });
      return;
    }

    setState(() {
      _zones.add({
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
      });
      _dragStart = null;
      _liveRect = null;
    });
  }

  void _deleteZone(int index) {
    setState(() => _zones.removeAt(index));
  }

  Future<void> _saveZones() async {
    setState(() => _isSaving = true);
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null) {
      setState(() => _isSaving = false);
      return;
    }
    try {
      await ref
          .read(settingsProvider.notifier)
          .applyUpdate(settings.copyWith(privacyZones: _zones));
      setState(() => _isSaving = false);
      if (mounted) DDToast.success(context, 'Privacy zones saved');
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) DDToast.error(context, 'Failed to save privacy zones.');
    }
  }

  void _clearAll() {
    DDConfirmSheet.show(
      context: context,
      title: 'Clear All Zones',
      message: 'Remove all privacy zones?',
      confirmLabel: 'Clear All',
      isDestructive: true,
      onConfirm: () => setState(() => _zones.clear()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

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
        title: Text('Privacy Zones', style: DDTypography.h3),
      ),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: DDLoadingIndicator(size: DDLoadingSize.md)),
        error: (_, __) => Center(
          child: Text('Could not load settings', style: DDTypography.bodyM),
        ),
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(DDSpacing.xl),
              child: Text(
                'Drag to draw zones where motion should be ignored. Tap × to remove a zone.',
                style: DDTypography.caption.copyWith(color: DDColors.textMuted),
              ),
            ),
            // Camera frame with zones overlay
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                        constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) => _onPanStart(d, size),
                      onPanUpdate: (d) => _onPanUpdate(d, size),
                      onPanEnd: _onPanEnd,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DDSpacing.radiusMd),
                        child: Container(
                          color: const Color(0xFF1A1A1A),
                          child: Stack(
                            children: [
                              // Placeholder camera view label
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam_outlined,
                                        color: Color(0xFF4A4A4A), size: 40),
                                    SizedBox(height: 8),
                                    Text(
                                      'Camera view',
                                      style: TextStyle(
                                        color: Color(0xFF6A6A6A),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Existing zones
                              for (int i = 0; i < _zones.length; i++)
                                _ZoneOverlay(
                                  zone: _zones[i],
                                  frameSize: size,
                                  onDelete: () => _deleteZone(i),
                                ),
                              // Live drawing rect
                              if (_liveRect != null)
                                Positioned(
                                  left: _liveRect!.left * size.width,
                                  top: _liveRect!.top * size.height,
                                  width: _liveRect!.width * size.width,
                                  height: _liveRect!.height * size.height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: DDColors.hunterGreen
                                          .withValues(alpha: 0.3),
                                      border: Border.all(
                                        color: DDColors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DDSpacing.xl, DDSpacing.sm, DDSpacing.xl, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DDColors.softGreenGray,
                      borderRadius:
                          BorderRadius.circular(DDSpacing.radiusFull),
                    ),
                    child: Text(
                      '${_zones.length}/$_maxZones zones',
                      style: DDTypography.caption.copyWith(
                        color: DDColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(DDSpacing.xl),
              child: Column(
                children: [
                  DDButton.primary(
                    label: 'Save Zones',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveZones,
                  ),
                  if (_zones.isNotEmpty) ...[
                    const SizedBox(height: DDSpacing.sm),
                    DDButton.destructive(
                      label: 'Clear All',
                      onPressed: _clearAll,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneOverlay extends StatelessWidget {
  final Map<String, double> zone;
  final Size frameSize;
  final VoidCallback onDelete;

  const _ZoneOverlay({
    required this.zone,
    required this.frameSize,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final x = (zone['x'] ?? 0) * frameSize.width;
    final y = (zone['y'] ?? 0) * frameSize.height;
    final w = (zone['width'] ?? 0) * frameSize.width;
    final h = (zone['height'] ?? 0) * frameSize.height;

    return Positioned(
      left: x,
      top: y,
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: DDColors.hunterGreen.withValues(alpha: 0.35),
          border: Border.all(color: DDColors.white, width: 1.5),
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: DDColors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  size: 12, color: DDColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
