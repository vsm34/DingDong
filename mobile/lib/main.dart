import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/dd_colors.dart';
import 'core/theme/dd_spacing.dart';
import 'core/theme/dd_theme.dart';
import 'core/theme/dd_typography.dart';
import 'navigation/app_router.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// FCM background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message received; navigation is handled when the user taps
  // the notification and the app opens via onMessageOpenedApp.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('settings');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: DingDongApp()));
}

class DingDongApp extends ConsumerStatefulWidget {
  const DingDongApp({super.key});

  @override
  ConsumerState<DingDongApp> createState() => _DingDongAppState();
}

class _DingDongAppState extends ConsumerState<DingDongApp> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  void _setupFcm() {
    // Foreground messages → check quiet hours, then show styled snackbar
    FirebaseMessaging.onMessage.listen((message) {
      final qhState = ref.read(quietHoursProvider).valueOrNull;
      if (qhState != null && qhState.isCurrentlyQuiet) return;

      final title = message.notification?.title ?? 'DingDong';
      final body = message.notification?.body ?? '';
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(_buildToastSnackBar('$title: $body'));
    });

    // Background/terminated notification tap → navigate to event
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
      if (message != null && mounted) _navigateFromMessage(message);
    });
  }

  void _navigateFromMessage(RemoteMessage message) {
    final eventId = message.data['eventId'] as String?;
    if (eventId != null) {
      ref.read(routerProvider).push(Routes.eventDetailPath(eventId));
    }
  }

  SnackBar _buildToastSnackBar(String message) {
    return SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_outlined,
              color: DDColors.white, size: 18),
          const SizedBox(width: DDSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: DDTypography.bodyM.copyWith(color: DDColors.white),
            ),
          ),
        ],
      ),
      backgroundColor: DDColors.textPrimary,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
      margin: const EdgeInsets.only(
        bottom: DDSpacing.xl,
        left: DDSpacing.lg,
        right: DDSpacing.lg,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'DingDong',
      theme: DDTheme.light,
      darkTheme: DDTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
