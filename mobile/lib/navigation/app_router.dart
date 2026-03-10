import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/account_settings_screen.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/onboarding/screens/connect_ap_screen.dart';
import '../features/onboarding/screens/provisioning_screen.dart';
import '../features/onboarding/screens/confirming_screen.dart';
import '../features/onboarding/screens/success_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/events/screens/events_feed_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/clips/screens/clips_list_screen.dart';
import '../features/clips/screens/clip_player_screen.dart';
import '../features/live_view/screens/live_view_screen.dart';
import '../features/settings/screens/device_settings_screen.dart';
import '../features/home/screens/home_settings_screen.dart';
import '../features/debug/screens/debug_screen.dart';

/// Route names
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const onboardWelcome = '/onboard/welcome';
  static const onboardConnectAp = '/onboard/connect-ap';
  static const onboardProvisioning = '/onboard/provisioning';
  static const onboardConfirming = '/onboard/confirming';
  static const onboardSuccess = '/onboard/success';
  static const homeEvents = '/home/events';
  static const homeClips = '/home/clips';
  static const homeLive = '/home/live';
  static const homeSettings = '/home/settings';
  static const eventDetail = '/events/:eventId';
  static const clipPlayer = '/clips/:clipId';
  static const deviceSettings = '/settings/device';
  static const accountSettings = '/settings/account';
  static const debug = '/debug';

  static String eventDetailPath(String eventId) => '/events/$eventId';
  static String clipPlayerPath(String clipId) => '/clips/$clipId';
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final path = state.uri.path;

      final isAuthRoute = path == Routes.login || path == Routes.signup;
      final isSplash = path == Routes.splash;
      final isOnboarding = path.startsWith('/onboard');

      if (isSplash) return null;
      if (!isAuth && !isAuthRoute && !isOnboarding) return Routes.login;
      if (isAuth && isAuthRoute) return Routes.homeEvents;

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, __) => const SignUpScreen(),
      ),
      // Onboarding wizard
      GoRoute(
        path: Routes.onboardWelcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.onboardConnectAp,
        builder: (_, __) => const ConnectApScreen(),
      ),
      GoRoute(
        path: Routes.onboardProvisioning,
        builder: (_, __) => const ProvisioningScreen(),
      ),
      GoRoute(
        path: Routes.onboardConfirming,
        builder: (_, __) => const ConfirmingScreen(),
      ),
      GoRoute(
        path: Routes.onboardSuccess,
        builder: (_, __) => const SuccessScreen(),
      ),
      // Home — bottom nav shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeEvents,
                builder: (_, __) => const EventsFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeClips,
                builder: (_, __) => const ClipsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeLive,
                builder: (_, __) => const LiveViewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeSettings,
                builder: (_, __) => const HomeSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Detail screens (outside shell)
      GoRoute(
        path: Routes.eventDetail,
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: Routes.clipPlayer,
        builder: (_, state) =>
            ClipPlayerScreen(clipId: state.pathParameters['clipId']!),
      ),
      GoRoute(
        path: Routes.deviceSettings,
        builder: (_, __) => const DeviceSettingsScreen(),
      ),
      GoRoute(
        path: Routes.accountSettings,
        builder: (_, __) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: Routes.debug,
        builder: (_, __) => const DebugScreen(),
      ),
    ],
  );
}

/// Provider for the router (needs WidgetRef, so built lazily)
final routerProvider = Provider<GoRouter>((ref) {
  // We build using a dummy container ref — screens use context.go()
  // The redirect closure will re-evaluate on auth changes
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.onboardWelcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.onboardConnectAp,
        builder: (_, __) => const ConnectApScreen(),
      ),
      GoRoute(
        path: Routes.onboardProvisioning,
        builder: (_, __) => const ProvisioningScreen(),
      ),
      GoRoute(
        path: Routes.onboardConfirming,
        builder: (_, __) => const ConfirmingScreen(),
      ),
      GoRoute(
        path: Routes.onboardSuccess,
        builder: (_, __) => const SuccessScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeEvents,
                builder: (_, __) => const EventsFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeClips,
                builder: (_, __) => const ClipsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeLive,
                builder: (_, __) => const LiveViewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.homeSettings,
                builder: (_, __) => const HomeSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.eventDetail,
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: Routes.clipPlayer,
        builder: (_, state) =>
            ClipPlayerScreen(clipId: state.pathParameters['clipId']!),
      ),
      GoRoute(
        path: Routes.deviceSettings,
        builder: (_, __) => const DeviceSettingsScreen(),
      ),
      GoRoute(
        path: Routes.accountSettings,
        builder: (_, __) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: Routes.debug,
        builder: (_, __) => const DebugScreen(),
      ),
    ],
  );
});
