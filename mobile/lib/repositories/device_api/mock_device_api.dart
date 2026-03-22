import 'dart:typed_data';
import 'device_api.dart';
import '../../models/event_model.dart';
import '../../models/clip_model.dart';
import '../../models/device_model.dart';
import '../../models/device_settings_model.dart';

/// Mock implementation of DeviceApi with realistic data
/// Used in Phase 1 — no real network calls
class MockDeviceApi implements DeviceApi {
  DeviceSettings _settings = DeviceSettings.defaults();
  final List<DdClip> _clips = List.unmodifiable(_mockClips());
  final List<DdEvent> _events = List.unmodifiable(_mockEvents());

  @override
  Future<HealthResponse> getHealth() async {
    await _fakeDelay();
    return HealthResponse(
      ok: true,
      deviceId: 'dd-001',
      fwVersion: '0.9.2',
      time: DateTime.now(),
      lastEventTs: DateTime.now().subtract(const Duration(minutes: 8)),
    );
  }

  @override
  Future<List<DdEvent>> getEvents({DateTime? since}) async {
    await _fakeDelay();
    if (since != null) {
      return _events.where((e) => e.timestamp.isAfter(since)).toList();
    }
    return List.of(_events);
  }

  @override
  Future<List<DdClip>> getClips() async {
    await _fakeDelay();
    return List.of(_clips);
  }

  @override
  Future<Uint8List> downloadClip(String clipId) async {
    await _fakeDelay(ms: 800);
    // Return empty bytes in mock — real playback not needed in Phase 1
    return Uint8List(0);
  }

  @override
  Future<void> deleteClip(String clipId) async {
    await _fakeDelay(ms: 400);
    // No-op in mock
  }

  @override
  Future<DeviceSettings> getSettings() async {
    await _fakeDelay();
    return _settings;
  }

  @override
  Future<void> updateSettings(DeviceSettings settings) async {
    await _fakeDelay(ms: 400);
    _settings = settings;
  }

  @override
  String getStreamUrl() {
    return 'http://dingdong-dd-001.local/api/v1/stream';
  }

  @override
  Future<Map<String, String>> getRequestHeaders() async => {};

  static Future<void> _fakeDelay({int ms = 600}) =>
      Future.delayed(Duration(milliseconds: ms));

  static List<DdEvent> _mockEvents() {
    final now = DateTime.now();
    return [
      DdEvent(
        id: 'evt-001',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(minutes: 8)),
        type: EventType.motion,
        clipId: 'clip-001',
        sensorStats:
            const SensorStats(pirTriggered: true, mmwaveDistance: 1.4),
      ),
      DdEvent(
        id: 'evt-002',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 22)),
        type: EventType.doorbell,
        clipId: 'clip-002',
        sensorStats: null,
      ),
      DdEvent(
        id: 'evt-003',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 5)),
        type: EventType.motion,
        clipId: 'clip-003',
        sensorStats:
            const SensorStats(pirTriggered: true, mmwaveDistance: 2.1),
      ),
      DdEvent(
        id: 'evt-004',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(hours: 5, minutes: 48)),
        type: EventType.motion,
        clipId: null,
        sensorStats:
            const SensorStats(pirTriggered: true, mmwaveDistance: 0.8),
      ),
      DdEvent(
        id: 'evt-005',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(hours: 7)),
        type: EventType.doorbell,
        clipId: 'clip-004',
        sensorStats: null,
      ),
      DdEvent(
        id: 'evt-006',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(hours: 18, minutes: 12)),
        type: EventType.motion,
        clipId: 'clip-005',
        sensorStats:
            const SensorStats(pirTriggered: true, mmwaveDistance: 1.9),
      ),
      DdEvent(
        id: 'evt-007',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        type: EventType.motion,
        clipId: null,
        sensorStats:
            const SensorStats(pirTriggered: false, mmwaveDistance: 3.2),
      ),
      DdEvent(
        id: 'evt-008',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(days: 1, hours: 8, minutes: 30)),
        type: EventType.doorbell,
        clipId: 'clip-006',
        sensorStats: null,
      ),
    ];
  }

  static List<DdClip> _mockClips() {
    final now = DateTime.now();
    return [
      DdClip(
        clipId: 'clip-001',
        timestamp: now.subtract(const Duration(minutes: 8)),
        durationSec: 10,
        sizeBytes: 1856000,
      ),
      DdClip(
        clipId: 'clip-002',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 22)),
        durationSec: 10,
        sizeBytes: 1920000,
      ),
      DdClip(
        clipId: 'clip-003',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 5)),
        durationSec: 20,
        sizeBytes: 3712000,
      ),
      DdClip(
        clipId: 'clip-004',
        timestamp: now.subtract(const Duration(hours: 7)),
        durationSec: 10,
        sizeBytes: 1792000,
      ),
      DdClip(
        clipId: 'clip-005',
        timestamp: now.subtract(const Duration(hours: 18, minutes: 12)),
        durationSec: 30,
        sizeBytes: 5570000,
      ),
      DdClip(
        clipId: 'clip-006',
        timestamp: now.subtract(const Duration(days: 1, hours: 8, minutes: 30)),
        durationSec: 10,
        sizeBytes: 1760000,
      ),
    ];
  }
}
