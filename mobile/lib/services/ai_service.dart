import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';

/// AiService — wraps AI feature calls.
/// generateEventSummary: uses Firebase callable Cloud Function.
/// sendSupportMessage: uses Dio HTTP POST to aiSupportChat Cloud Function
///   (onRequest with CORS) to avoid callable CORS issues on Flutter web.
class AiService {
  final FirebaseFunctions _functions;

  static const _chatUrl =
      'https://us-central1-dingdong-596c2.cloudfunctions.net/aiSupportChat';

  static const _systemPrompt =
      'You are DingDong Support, a helpful assistant for the DingDong smart '
      'doorbell system. DingDong is a privacy-first doorbell that stores all '
      'video locally on a microSD card with no cloud subscription required. '
      'It uses dual-sensor detection (PIR + mmWave radar) to reduce false '
      'alerts. The mobile app connects to the device over local Wi-Fi. '
      'Key features: motion detection, doorbell button, live view on LAN, '
      'clip playback, push notifications via Firebase, device onboarding via '
      'SoftAP. Common issues: device offline means not on same Wi-Fi network, '
      'clips only available on home network, notifications require FCM token '
      'registered. Answer questions helpfully and concisely. If you do not '
      'know something specific about the user\'s setup, say so. Keep responses '
      'under 100 words.';

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

  /// Sends the conversation history to the aiSupportChat Cloud Function via
  /// Dio HTTP POST (bypasses callable CORS issues on Flutter web).
  Future<String> sendSupportMessage(
      List<Map<String, String>> messages) async {
    try {
      // Step 1: get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('user is null');
        return 'Please sign in to use support chat.';
      }

      // Step 2: get ID token
      String idToken;
      try {
        idToken = await user.getIdToken() ?? '';
        if (idToken.isEmpty) {
          return 'Authentication error. Please sign out and sign in again.';
        }
      } catch (e) {
        debugPrint('getIdToken error: $e');
        return 'Authentication error. Please sign out and sign in again.';
      }

      // Step 3: build request body
      final body = {
        'model': 'claude-3-haiku-20240307',
        'max_tokens': 200,
        'system': _systemPrompt,
        'messages': messages,
      };

      // Step 4: make Dio POST with explicit timeouts
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ));

      final response = await dio.post<dynamic>(_chatUrl, data: body);

      // Step 5: parse response
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return data['reply'] as String? ??
              "Sorry, I'm having trouble connecting. Please try again.";
        }
        if (data is String) {
          try {
            final parsed = jsonDecode(data) as Map<String, dynamic>;
            return parsed['reply'] as String? ??
                "Sorry, I'm having trouble connecting. Please try again.";
          } catch (_) {
            // fall through
          }
        }
      }
      return "Sorry, I'm having trouble connecting. Please try again.";
    } catch (e) {
      debugPrint('aiSupportChat error: $e');
      return "Sorry, I'm having trouble connecting. Please try again.";
    }
  }
}
