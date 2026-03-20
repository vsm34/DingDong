import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../repositories/device_api/device_api.dart';
import '../repositories/device_api/mock_device_api.dart';
import '../repositories/events/events_repo.dart';
import '../repositories/events/firestore_events_repo.dart';
import '../models/event_model.dart';
import '../models/clip_model.dart';
import '../models/device_model.dart';
import '../models/device_settings_model.dart';

// ─── Repository providers ────────────────────────────────────────────────────

final deviceApiProvider = Provider<DeviceApi>((ref) => MockDeviceApi());

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

final mockDevice = DdDevice(
  deviceId: 'dd-001',
  displayName: 'Front Door',
  ownerId: 'mock-uid-001',
  createdAt: DateTime.now().subtract(const Duration(days: 14)),
  lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
  firmwareVersion: '0.9.2',
  notifyEnabled: true,
  motionEnabled: true,
);

final deviceProvider = StateProvider<DdDevice>((ref) => mockDevice);

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

// ─── LAN reachability (mock: always reachable in Phase 1) ───────────────────

final lanReachableProvider = StateProvider<bool>((ref) => true);
