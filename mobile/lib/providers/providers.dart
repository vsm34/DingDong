import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/device_api/device_api.dart';
import '../repositories/device_api/mock_device_api.dart';
import '../repositories/events/events_repo.dart';
import '../repositories/events/mock_events_repo.dart';
import '../models/event_model.dart';
import '../models/clip_model.dart';
import '../models/device_model.dart';
import '../models/device_settings_model.dart';

// ─── Repository providers ────────────────────────────────────────────────────

final deviceApiProvider = Provider<DeviceApi>((ref) => MockDeviceApi());

final eventsRepoProvider = Provider<EventsRepo>((ref) => MockEventsRepo());

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
    // Phase 1: start as logged in with mock user
    return const AuthState(
      user: AuthUser(
        uid: 'mock-uid-001',
        email: 'test@dingdong.com',
        displayName: 'Demo User',
      ),
    );
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthState(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 800));
    state = AuthState(
      user: AuthUser(
        uid: 'mock-uid-001',
        email: email,
        displayName: email.split('@').first,
      ),
    );
  }

  Future<void> signUp(
      String email, String password, String displayName) async {
    state = const AuthState(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 900));
    state = AuthState(
      user: AuthUser(
        uid: 'mock-uid-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
      ),
    );
  }

  void signOut() {
    state = const AuthState();
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
