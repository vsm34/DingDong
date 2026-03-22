import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clip_model.dart';
import '../models/device_model.dart';
import '../models/device_settings_model.dart';
import '../models/event_model.dart';
import '../repositories/device_api/device_api.dart';
import '../repositories/device_api/real_device_api.dart';
import '../repositories/events/events_repo.dart';
import '../repositories/events/firestore_events_repo.dart';

// ─── Repository providers ────────────────────────────────────────────────────

/// Device API provider — uses the real ESP32 HTTP API.
/// Rebuilds automatically if deviceProvider.deviceId changes.
final deviceApiProvider = Provider<DeviceApi>((ref) {
  final device = ref.watch(deviceProvider);
  return RealDeviceApi(deviceId: device.deviceId);
});

final eventsRepoProvider = Provider<EventsRepo>((ref) => FirestoreEventsRepo());

// ─── Auth ─────────────────────────────────────────────────────────────────────

class AuthUser {
  final String uid;
  final String email;
  final String displayName;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });
}

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Keep state in sync with Firebase auth changes
    final sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        state = AuthState(
          user: AuthUser(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          ),
        );
      } else {
        state = const AuthState();
      }
    });
    ref.onDispose(sub.cancel);

    if (firebaseUser == null) return const AuthState();
    return AuthState(
      user: AuthUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
      ),
    );
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _registerFcmToken(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      state = AuthState(error: e.message);
    }
  }

  Future<void> signUp(
      String email, String password, String displayName) async {
    state = const AuthState(isLoading: true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateDisplayName(displayName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmTokens': <String>[],
      });
      await _registerFcmToken(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      state = AuthState(error: e.message);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _unregisterFcmToken(user.uid);
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _registerFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmTokens': FieldValue.arrayUnion([token])},
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Non-fatal — sign-in succeeds even if FCM token registration fails
    }
  }

  Future<void> _unregisterFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmTokens': FieldValue.arrayRemove([token])});
      }
    } catch (_) {
      // Non-fatal
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ─── Device ──────────────────────────────────────────────────────────────────

final _defaultDevice = DdDevice(
  deviceId: 'dd-001',
  displayName: 'Front Door',
  ownerId: 'mock-uid-001',
  createdAt: DateTime.now().subtract(const Duration(days: 14)),
  lastSeen: null,
  firmwareVersion: null,
  notifyEnabled: true,
  motionEnabled: true,
);

final deviceProvider = StateProvider<DdDevice>((ref) => _defaultDevice);

final deviceHealthProvider = FutureProvider<HealthResponse>((ref) async {
  final api = ref.watch(deviceApiProvider);
  return api.getHealth();
});

// ─── Events ──────────────────────────────────────────────────────────────────

final eventsProvider = FutureProvider<List<DdEvent>>((ref) async {
  final repo = ref.watch(eventsRepoProvider);
  final device = ref.watch(deviceProvider);
  return repo.getEvents(deviceId: device.deviceId);
});

final eventDetailProvider =
    FutureProvider.family<DdEvent?, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepoProvider);
  return repo.getEvent(eventId);
});

// ─── Clips ───────────────────────────────────────────────────────────────────

final clipsProvider = FutureProvider<List<DdClip>>((ref) async {
  final api = ref.watch(deviceApiProvider);
  return api.getClips();
});

// ─── Settings ────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<DeviceSettings> {
  @override
  Future<DeviceSettings> build() async {
    final api = ref.watch(deviceApiProvider);
    return api.getSettings();
  }

  Future<void> applyUpdate(DeviceSettings settings) async {
    final api = ref.read(deviceApiProvider);
    final previous = state.value;
    state = AsyncData(settings);
    try {
      await api.updateSettings(settings);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, DeviceSettings>(
        SettingsNotifier.new);

// ─── Onboarding ──────────────────────────────────────────────────────────────

enum OnboardingStep {
  welcome,
  connectAp,
  provisioning,
  confirming,
  success,
}

class OnboardingState {
  final OnboardingStep step;
  final bool isLoading;
  final String? error;
  final String? deviceName;
  final String? wifiSsid;

  const OnboardingState({
    this.step = OnboardingStep.welcome,
    this.isLoading = false,
    this.error,
    this.deviceName,
    this.wifiSsid,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    bool? isLoading,
    String? error,
    String? deviceName,
    String? wifiSsid,
  }) =>
      OnboardingState(
        step: step ?? this.step,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        deviceName: deviceName ?? this.deviceName,
        wifiSsid: wifiSsid ?? this.wifiSsid,
      );
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void advance(OnboardingStep step) {
    state = state.copyWith(step: step, isLoading: false);
  }

  void setDeviceName(String name) {
    state = state.copyWith(deviceName: name);
  }

  void setWifiSsid(String ssid) {
    state = state.copyWith(wifiSsid: ssid);
  }

  Future<void> simulateProvisioning() async {
    state = state.copyWith(step: OnboardingStep.provisioning, isLoading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(step: OnboardingStep.confirming, isLoading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(step: OnboardingStep.success, isLoading: false);
  }

  void reset() {
    state = const OnboardingState();
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
        OnboardingNotifier.new);

// ─── LAN reachability ────────────────────────────────────────────────────────
//
// Polls GET /health every 30 seconds.
// On success: marks device online, updates deviceProvider.lastSeen, writes
// lastSeen to Firestore.
// On failure / timeout: marks device offline.
// Call checkNow() to trigger an immediate probe (e.g., on app foreground).

class LanReachabilityNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _check(),
    );
    // Run an immediate check without blocking build()
    Future.microtask(_check);
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Trigger an immediate LAN probe. Safe to call from WidgetsBindingObserver.
  Future<void> checkNow() => _check();

  /// Debug/testing only — force override the reachability state.
  // ignore: avoid_positional_boolean_parameters
  void debugOverride(bool value) => state = value;

  Future<void> _check() async {
    try {
      final api = ref.read(deviceApiProvider);
      final health =
          await api.getHealth().timeout(const Duration(seconds: 5));
      state = health.ok;
      if (health.ok) {
        final now = DateTime.now();
        final device = ref.read(deviceProvider);
        // Update lastSeen + firmwareVersion in local state
        ref.read(deviceProvider.notifier).state = device.copyWith(
          lastSeen: now,
          firmwareVersion: health.fwVersion,
        );
        // Store signal strength
        ref.read(signalStrengthProvider.notifier).state = health.signalStrength;
        // Persist lastSeen to Firestore (non-fatal)
        _writeFirestoreLastSeen(device.deviceId);
      }
    } catch (_) {
      state = false;
    }
  }

  void _writeFirestoreLastSeen(String deviceId) {
    FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .update({'lastSeen': FieldValue.serverTimestamp()})
        .ignore();
  }
}

final lanReachableProvider =
    NotifierProvider<LanReachabilityNotifier, bool>(
        LanReachabilityNotifier.new);

// ─── Quiet hours ──────────────────────────────────────────────────────────────

class QuietHoursState {
  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;

  const QuietHoursState({
    this.enabled = false,
    this.start = const TimeOfDay(hour: 22, minute: 0),
    this.end = const TimeOfDay(hour: 7, minute: 0),
  });

  QuietHoursState copyWith({
    bool? enabled,
    TimeOfDay? start,
    TimeOfDay? end,
  }) =>
      QuietHoursState(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  /// Returns true if the current time falls within the quiet window.
  bool get isCurrentlyQuiet {
    if (!enabled) return false;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (startMin <= endMin) {
      return nowMin >= startMin && nowMin < endMin;
    } else {
      // Wraps midnight
      return nowMin >= startMin || nowMin < endMin;
    }
  }
}

class QuietHoursNotifier extends AsyncNotifier<QuietHoursState> {
  @override
  Future<QuietHoursState> build() async {
    final device = ref.watch(deviceProvider);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .get();
      if (!doc.exists) return const QuietHoursState();
      final data = doc.data()!;
      return QuietHoursState(
        enabled: (data['quietHoursEnabled'] as bool?) ?? false,
        start: _minutesToTime((data['quietHoursStart'] as int?) ?? 22 * 60),
        end: _minutesToTime((data['quietHoursEnd'] as int?) ?? 7 * 60),
      );
    } catch (_) {
      return const QuietHoursState();
    }
  }

  Future<void> save(QuietHoursState updated) async {
    state = AsyncData(updated);
    final device = ref.read(deviceProvider);
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .update({
        'quietHoursEnabled': updated.enabled,
        'quietHoursStart': updated.start.hour * 60 + updated.start.minute,
        'quietHoursEnd': updated.end.hour * 60 + updated.end.minute,
      });
    } catch (_) {
      // Non-fatal — Firestore may not have this field yet; ignore
    }
  }

  static TimeOfDay _minutesToTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

final quietHoursProvider =
    AsyncNotifierProvider<QuietHoursNotifier, QuietHoursState>(
        QuietHoursNotifier.new);

// ─── Device membership ────────────────────────────────────────────────────────
//
// Returns true if the current user has at least one device in deviceMembers.

final deviceMembershipProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return false;
  final uid = auth.user!.uid;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('deviceMembers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  } catch (_) {
    return true; // Fail open — avoid false onboarding redirects
  }
});

// ─── Motion schedule ──────────────────────────────────────────────────────────

class MotionScheduleState {
  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;

  const MotionScheduleState({
    this.enabled = false,
    this.start = const TimeOfDay(hour: 6, minute: 0),
    this.end = const TimeOfDay(hour: 22, minute: 0),
  });

  MotionScheduleState copyWith({
    bool? enabled,
    TimeOfDay? start,
    TimeOfDay? end,
  }) =>
      MotionScheduleState(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

class MotionScheduleNotifier extends AsyncNotifier<MotionScheduleState> {
  @override
  Future<MotionScheduleState> build() async {
    final device = ref.watch(deviceProvider);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .get();
      if (!doc.exists) return const MotionScheduleState();
      final data = doc.data()!;
      return MotionScheduleState(
        enabled: (data['motionScheduleEnabled'] as bool?) ?? false,
        start: _minutesToTime((data['motionScheduleStart'] as int?) ?? 6 * 60),
        end: _minutesToTime((data['motionScheduleEnd'] as int?) ?? 22 * 60),
      );
    } catch (_) {
      return const MotionScheduleState();
    }
  }

  Future<void> save(MotionScheduleState updated) async {
    state = AsyncData(updated);
    final device = ref.read(deviceProvider);
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .update({
        'motionScheduleEnabled': updated.enabled,
        'motionScheduleStart': updated.start.hour * 60 + updated.start.minute,
        'motionScheduleEnd': updated.end.hour * 60 + updated.end.minute,
      });
    } catch (_) {
      // Non-fatal
    }
  }

  static TimeOfDay _minutesToTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

final motionScheduleProvider =
    AsyncNotifierProvider<MotionScheduleNotifier, MotionScheduleState>(
        MotionScheduleNotifier.new);

// ─── Signal strength (from LAN health) ───────────────────────────────────────

final signalStrengthProvider = StateProvider<int?>((ref) => null);
