import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_typography.dart';

/// Controller for [MjpegView] — lets the parent widget pause/resume streaming
/// when the app goes to background or the screen is not visible.
class MjpegController {
  _MjpegViewState? _state;

  void _attach(_MjpegViewState state) => _state = state;
  void _detach() => _state = null;

  /// Stop the stream (e.g., on app pause).
  void stop() => _state?._stop();

  /// Resume the stream (e.g., on app resume).
  void start() => _state?._start();
}

/// MJPEG live-stream viewer.
///
/// - **Web**: delegates to [Image.network] — browsers handle
///   `multipart/x-mixed-replace` natively.
/// - **Android/iOS**: reads the raw HTTP response stream using Dio, extracts
///   individual JPEG frames by scanning for SOI (0xFF 0xD8) and EOI (0xFF 0xD9)
///   markers, and renders each frame with [Image.memory].
///
/// Reconnects automatically after 3 seconds on any connection error.
class MjpegView extends StatefulWidget {
  final String streamUrl;
  final Map<String, String> headers;
  final MjpegController? controller;

  const MjpegView({
    super.key,
    required this.streamUrl,
    this.headers = const {},
    this.controller,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _frame;
  bool _isConnecting = false;
  bool _hasError = false;
  bool _stopped = false;

  CancelToken? _cancelToken;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (!kIsWeb) _start();
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _retryTimer?.cancel();
    _cancelToken?.cancel('disposed');
    super.dispose();
  }

  void _stop() {
    _stopped = true;
    _retryTimer?.cancel();
    _cancelToken?.cancel('stream paused');
    if (mounted) setState(() => _isConnecting = false);
  }

  void _start() {
    _stopped = false;
    _connect();
  }

  Future<void> _connect() async {
    if (!mounted || _stopped) return;
    setState(() {
      _isConnecting = true;
      _hasError = false;
    });

    _cancelToken = CancelToken();

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      final resp = await dio.get<ResponseBody>(
        widget.streamUrl,
        options: Options(
          headers: Map<String, dynamic>.from(widget.headers),
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );

      if (mounted) setState(() => _isConnecting = false);

      await _parseStream(resp.data!.stream);

      // Stream ended without cancellation — schedule reconnect
      if (!_stopped) _scheduleReconnect();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || _stopped) return;
      _scheduleReconnect();
    } catch (_) {
      if (_stopped) return;
      _scheduleReconnect();
    }
  }

  /// Parses the raw multipart byte stream by scanning for JPEG SOI/EOI markers.
  /// Extracts each complete JPEG and updates [_frame].
  Future<void> _parseStream(Stream<Uint8List> stream) async {
    final buf = <int>[];

    await for (final chunk in stream) {
      if (_stopped) return;
      buf.addAll(chunk);

      // Keep scanning the buffer for complete JPEG frames
      while (buf.length >= 4) {
        // Find SOI marker (0xFF 0xD8)
        int soiIdx = -1;
        for (int i = 0; i < buf.length - 1; i++) {
          if (buf[i] == 0xFF && buf[i + 1] == 0xD8) {
            soiIdx = i;
            break;
          }
        }
        if (soiIdx == -1) {
          // No SOI — discard all bytes except the last one
          if (buf.length > 1) buf.removeRange(0, buf.length - 1);
          break;
        }
        // Drop any bytes before SOI
        if (soiIdx > 0) buf.removeRange(0, soiIdx);

        // Find EOI marker (0xFF 0xD9) — start searching after SOI
        int eoiIdx = -1;
        for (int i = 2; i < buf.length - 1; i++) {
          if (buf[i] == 0xFF && buf[i + 1] == 0xD9) {
            eoiIdx = i;
            break;
          }
        }
        if (eoiIdx == -1) break; // Need more data

        // Extract the complete JPEG frame
        final frame = Uint8List.fromList(buf.sublist(0, eoiIdx + 2));
        buf.removeRange(0, eoiIdx + 2);

        if (mounted) setState(() => _frame = frame);
      }
    }
  }

  void _scheduleReconnect() {
    if (!mounted || _stopped) return;
    setState(() {
      _hasError = true;
      _isConnecting = false;
    });
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_stopped) _connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Web ──────────────────────────────────────────────────────────────────
    if (kIsWeb) {
      return Image.network(
        widget.streamUrl,
        headers: widget.headers,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ErrorState(),
      );
    }

    // ── Android / iOS ────────────────────────────────────────────────────────
    if (_isConnecting && _frame == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: DDColors.hunterGreen,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_frame == null || (_hasError && _frame == null)) {
      return const _ErrorState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _frame!,
          gaplessPlayback: true,
          fit: BoxFit.contain,
        ),
        if (_hasError)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Reconnecting...',
                  style:
                      DDTypography.caption.copyWith(color: Colors.white70),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_wifi_off, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            'Reconnecting...',
            style: DDTypography.caption.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
