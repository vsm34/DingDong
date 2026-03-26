import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';

/// AiService — wraps AI feature calls.
/// generateEventSummary: uses Firebase callable Cloud Function.
/// sendSupportMessage: uses Dio HTTP POST to aiSupportChat Cloud Function
///   (onRequest with CORS) to avoid callable CORS issues on Flutter web.
class AiService {
  final FirebaseFunctions _functions;
  final Dio _dio;

  static const _chatUrl =
      'https://us-central1-dingdong-596c2.cloudfunctions.net/aiSupportChat';

  AiService({FirebaseFunctions? functions, Dio? dio})
      : _functions = functions ?? FirebaseFunctions.instance,
        _dio = dio ?? Dio();

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

  /// Sends the conversation history to the aiSupportChat Cloud Function via
  /// Dio HTTP POST (bypasses callable CORS issues on Flutter web).
  Future<String> sendSupportMessage(
      List<Map<String, String>> messages) async {
    const fallback =
        "Sorry, I'm having trouble connecting. Please try again.";
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return fallback;

      final response = await _dio.post<Map<String, dynamic>>(
        _chatUrl,
        data: {'messages': messages},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      return data?['reply'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
