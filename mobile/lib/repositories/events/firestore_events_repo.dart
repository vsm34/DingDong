import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';
import 'events_repo.dart';

/// FirestoreEventsRepo — reads events from Firestore events collection.
/// Schema per PRD Section 6.1.
class FirestoreEventsRepo implements EventsRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<DdEvent>> getEvents({
    String? deviceId,
    DateTime? since,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('events');

    if (deviceId != null) {
      query = query.where('deviceId', isEqualTo: deviceId);
    }
    if (since != null) {
      query = query.where('ts', isGreaterThan: Timestamp.fromDate(since));
    }
    query = query.orderBy('ts', descending: true);

    final snapshot = await query.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Stream<List<DdEvent>> watchEvents(String deviceId) {
    return _db
        .collection('events')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('ts', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<DdEvent?> getEvent(String eventId) async {
    final doc = await _db.collection('events').doc(eventId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  DdEvent _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ts = (data['ts'] as Timestamp).toDate();
    final statsData = data['sensorStats'] as Map<String, dynamic>?;

    return DdEvent(
      id: doc.id,
      deviceId: data['deviceId'] as String,
      timestamp: ts,
      type: data['type'] == 'doorbell' ? EventType.doorbell : EventType.motion,
      clipId: data['clipId'] as String?,
      sensorStats: statsData != null
          ? SensorStats(
              pirTriggered: statsData['pirTriggered'] as bool,
              mmwaveDistance: (statsData['mmwaveDistance'] as num?)?.toDouble(),
            )
          : null,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
