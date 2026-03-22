import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/clip_model.dart';
import '../../models/device_model.dart';
import '../../models/device_settings_model.dart';
import '../../models/event_model.dart';
import 'device_api.dart';

/// Real DeviceApi — calls the ESP32 via mDNS URL using Dio.
/// - 5 second timeout on all calls
/// - 2 retries with exponential backoff on network/server errors (not 4xx)
/// - Bearer token read from flutter_secure_storage
/// - Stream URL: http://dingdong-<deviceId>.local/api/v1/stream
class RealDeviceApi implements DeviceApi {
  final String deviceId;

  static const _tokenKey = 'device_api_token';
  static const _apiPath = '/api/v1';
  static const _maxRetries = 2;

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  RealDeviceApi({required this.deviceId})
      : _storage = const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
  }

  String get _baseUrl => 'http://dingdong-$deviceId.local$_apiPath';

  Future<String?> _readToken() => _storage.read(key: _tokenKey);

  Future<Options> _opts({ResponseType? responseType}) async {
    final token = await _readToken();
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers, responseType: responseType);
  }

  /// Retries up to [_maxRetries] times with exponential backoff.
  /// Does not retry on 4xx client errors.
  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500) rethrow;
        attempt++;
        if (attempt > _maxRetries) rethrow;
        await Future<void>.delayed(
            Duration(milliseconds: 500 * (1 << (attempt - 1))));
      }
    }
  }

  @override
  Future<HealthResponse> getHealth() => _withRetry(() async {
        final resp = await _dio.get<Map<String, dynamic>>(
          '/health',
          options: await _opts(),
        );
        return HealthResponse.fromJson(resp.data!);
      });

  @override
  Future<List<DdEvent>> getEvents({DateTime? since}) =>
      _withRetry(() async {
        final query = since != null
            ? {'since': since.millisecondsSinceEpoch.toString()}
            : <String, String>{};
        final resp = await _dio.get<Map<String, dynamic>>(
          '/events',
          queryParameters: query,
          options: await _opts(),
        );
        final list = resp.data!['events'] as List<dynamic>;
        return list
            .map((e) => DdEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<DdClip>> getClips() => _withRetry(() async {
        final resp = await _dio.get<Map<String, dynamic>>(
          '/clips',
          options: await _opts(),
        );
        final list = resp.data!['clips'] as List<dynamic>;
        return list
            .map((e) => DdClip.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Uint8List> downloadClip(String clipId) =>
      _withRetry(() async {
        final resp = await _dio.get<List<int>>(
          '/clips/$clipId',
          options: await _opts(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(resp.data!);
      });

  @override
  Future<void> deleteClip(String clipId) => _withRetry(() async {
        await _dio.delete<void>(
          '/clips/$clipId',
          options: await _opts(),
        );
      });

  @override
  Future<DeviceSettings> getSettings() => _withRetry(() async {
        final resp = await _dio.get<Map<String, dynamic>>(
          '/settings',
          options: await _opts(),
        );
        return DeviceSettings.fromJson(resp.data!);
      });

  @override
  Future<void> updateSettings(DeviceSettings settings) =>
      _withRetry(() async {
        await _dio.post<void>(
          '/settings',
          data: settings.toJson(),
          options: await _opts(),
        );
      });

  @override
  String getStreamUrl() =>
      'http://dingdong-$deviceId.local$_apiPath/stream';

  @override
  Future<Map<String, String>> getRequestHeaders() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }
}
