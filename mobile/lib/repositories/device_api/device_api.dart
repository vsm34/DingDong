import 'dart:typed_data';
import '../../models/event_model.dart';
import '../../models/clip_model.dart';
import '../../models/device_model.dart';
import '../../models/device_settings_model.dart';

/// Abstract interface for the ESP32 device HTTP API
abstract class DeviceApi {
  /// GET /health
  Future<HealthResponse> getHealth();

  /// GET /events?since=<ts>
  Future<List<DdEvent>> getEvents({DateTime? since});

  /// GET /clips
  Future<List<DdClip>> getClips();

  /// GET /clips/{clipId} — returns raw bytes
  Future<Uint8List> downloadClip(String clipId);

  /// DELETE /clips/{clipId}
  Future<void> deleteClip(String clipId);

  /// GET /settings
  Future<DeviceSettings> getSettings();

  /// POST /settings
  Future<void> updateSettings(DeviceSettings settings);

  /// Returns the MJPEG stream URL for the live view tab
  /// Format: http://dingdong-<deviceId>.local/api/v1/stream
  String getStreamUrl();

  /// Returns auth headers for direct HTTP calls (e.g., MJPEG stream)
  Future<Map<String, String>> getRequestHeaders();
}
