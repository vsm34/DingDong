import 'dart:async';
import 'events_repo.dart';
import '../../models/event_model.dart';

/// Mock implementation of EventsRepo with realistic data
/// Phase 1 only — replaced by FirestoreEventsRepo in Phase 2
class MockEventsRepo implements EventsRepo {
  final List<DdEvent> _events = _buildMockEvents();

  @override
  Future<List<DdEvent>> getEvents({
    String? deviceId,
    DateTime? since,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    var results = List.of(_events);
    if (deviceId != null) {
      results = results.where((e) => e.deviceId == deviceId).toList();
    }
    if (since != null) {
      results = results.where((e) => e.timestamp.isAfter(since)).toList();
    }
    // Most recent first
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  @override
  Stream<List<DdEvent>> watchEvents(String deviceId) {
    // In mock, emit once and then every 30 seconds simulate a new event
    final controller = StreamController<List<DdEvent>>();
    () async {
      final initial = List.of(_events)
          .where((e) => e.deviceId == deviceId)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(initial);

      // Simulate a new event after 15s for demo realism
      await Future.delayed(const Duration(seconds: 15));
      if (!controller.isClosed) {
        final updated = List.of(initial)
          ..insert(
            0,
            DdEvent(
              id: 'evt-live-${DateTime.now().millisecondsSinceEpoch}',
              deviceId: deviceId,
              timestamp: DateTime.now(),
              type: EventType.motion,
              clipId: null,
              sensorStats:
                  const SensorStats(pirTriggered: true, mmwaveDistance: 1.1),
            ),
          );
        controller.add(updated);
      }
    }();
    return controller.stream;
  }

  @override
  Future<DdEvent?> getEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      return _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }

  static List<DdEvent> _buildMockEvents() {
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
      DdEvent(
        id: 'evt-009',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
        type: EventType.motion,
        clipId: 'clip-007',
        sensorStats:
            const SensorStats(pirTriggered: true, mmwaveDistance: 1.7),
      ),
      DdEvent(
        id: 'evt-010',
        deviceId: 'dd-001',
        timestamp: now.subtract(const Duration(days: 3, hours: 1, minutes: 15)),
        type: EventType.doorbell,
        clipId: null,
        sensorStats: null,
      ),
    ];
  }
}
