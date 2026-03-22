import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../components/dd_logo.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /splash — Full white background.
/// DingDong logo hero centered with fade-in (0→1, 600ms, ease-in).
/// Auto-navigates after auth state check.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await _requestPermissionsIfNeeded();
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      context.go(Routes.homeEvents);
    } else {
      context.go(Routes.login);
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (kIsWeb) return;
    final box = Hive.box('settings');
    final alreadyRequested =
        box.get('permissions_requested', defaultValue: false) as bool;
    if (alreadyRequested) return;
    await Permission.notification.request();
    await box.put('permissions_requested', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: const DDLogo.hero(),
        ),
      ),
    );
  }
}
