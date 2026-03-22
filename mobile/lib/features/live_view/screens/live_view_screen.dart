import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../providers/providers.dart';
import '../../../repositories/device_api/device_api.dart';
import '../widgets/mjpeg_view.dart';

/// /home/live — Live view tab.
/// On LAN: full-width MJPEG frame (4:3), LIVE badge top-left, quality dot top-right.
/// Tap → overlay with stream info. Off LAN: offline state.
class LiveViewScreen extends ConsumerWidget {
  const LiveViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLanReachable = ref.watch(lanReachableProvider);
    final api = ref.watch(deviceApiProvider);

    if (!isLanReachable) return const _OfflineState();
    return _LiveStream(streamUrl: api.getStreamUrl(), api: api);
  }
}

class _LiveStream extends StatefulWidget {
  final String streamUrl;
  final DeviceApi api;

  const _LiveStream({required this.streamUrl, required this.api});

  @override
  State<_LiveStream> createState() => _LiveStreamState();
}

class _LiveStreamState extends State<_LiveStream>
    with WidgetsBindingObserver {
  bool _showOverlay = false;
  Map<String, String> _headers = {};
  bool _headersLoaded = false;
  final _controller = MjpegController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHeaders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadHeaders() async {
    final h = await widget.api.getRequestHeaders();
    if (mounted) {
      setState(() {
        _headers = h;
        _headersLoaded = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_headersLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: DDColors.hunterGreen,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          children: [
            // MJPEG stream
            Center(
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: MjpegView(
                  streamUrl: widget.streamUrl,
                  headers: _headers,
                  controller: _controller,
                ),
              ),
            ),
            // LIVE badge — top-left
            Positioned(
              top: MediaQuery.of(context).padding.top + DDSpacing.md,
              left: DDSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DDColors.error,
                  borderRadius:
                      BorderRadius.circular(DDSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: DDTypography.label.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Connection quality indicator — top-right
            Positioned(
              top: MediaQuery.of(context).padding.top + DDSpacing.md,
              right: DDSpacing.md,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: DDColors.online,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Tap overlay — resolution + close
            if (_showOverlay)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'QVGA 320×240 · MJPEG',
                        style: DDTypography.mono
                            .copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: DDSpacing.md),
                      IconButton(
                        onPressed: () =>
                            setState(() => _showOverlay = false),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off,
                  size: 64, color: DDColors.textMuted),
              const SizedBox(height: DDSpacing.lg),
              Text('Live View unavailable', style: DDTypography.h3),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'Connect to your home Wi-Fi to view the live stream.',
                style: DDTypography.bodyM
                    .copyWith(color: DDColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
