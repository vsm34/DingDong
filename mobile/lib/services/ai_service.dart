import 'package:cloud_functions/cloud_functions.dart';
import '../models/event_model.dart';

/// AiService — wraps Cloud Function calls for AI features.
/// generateEventSummary: calls generateEventSummary Cloud Function.
/// sendSupportMessage: calls aiSupportChat Cloud Function.
class AiService {
  final FirebaseFunctions _functions;

  AiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Generates a one-sentence summary for the given event.
  /// Returns null on failure.
  Future<String?> generateEventSummary(
      DdEvent event, String deviceName) async {
    try {
      final callable =
          _functions.httpsCallable('generateEventSummary');
      final result = await callable.call<Map<Object?, Object?>>({
        'eventId': event.id,
        'eventType': event.type.name,
        'timestamp': event.timestamp.millisecondsSinceEpoch,
        'sensorStats': event.sensorStats != null
            ? {
                'pirTriggered': event.sensorStats!.pirTriggered,
                'mmwaveDistance': event.sensorStats!.mmwaveDistance,
              }
            : null,
        'deviceName': deviceName,
      });
      final data = result.data;
      return data['summary'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Sends the conversation history to the support chat Cloud Function.
  /// Returns the assistant reply string.
  Future<String> sendSupportMessage(
      List<Map<String, String>> messages) async {
    try {
      final callable = _functions.httpsCallable('aiSupportChat');
      final result = await callable.call<Map<Object?, Object?>>({
        'messages': messages,
      });
      final data = result.data;
      return data['reply'] as String? ??
          "Sorry, I'm having trouble connecting. Please try again.";
    } catch (_) {
      return "Sorry, I'm having trouble connecting. Please try again.";
    }
  }
}
