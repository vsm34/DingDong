import '../../models/event_model.dart';

/// Abstract interface for the events data source
/// Phase 1: MockEventsRepo | Phase 2: FirestoreEventsRepo
abstract class EventsRepo {
  /// Fetch all events, optionally filtered by deviceId and/or since timestamp
  Future<List<DdEvent>> getEvents({
    String? deviceId,
    DateTime? since,
  });

  /// Watch live updates for a device's events (stream)
  Stream<List<DdEvent>> watchEvents(String deviceId);

  /// Fetch a single event by id
  Future<DdEvent?> getEvent(String eventId);
}
