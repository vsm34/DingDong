import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../components/dd_logo.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /splash — Full white background.
/// DingDong logo hero size centered vertically at 40% from top.
/// DDLoadingIndicator lg beneath logo.
/// Auto-navigates after auth state check.
/// 200ms scale-in animation (0.8 → 1.0, ease-out).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      context.go(Routes.homeEvents);
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: Stack(
        children: [
          // Logo positioned at ~40% from top
          Positioned(
            top: MediaQuery.of(context).size.height * 0.30,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: const Center(
                child: DDLogo.hero(),
              ),
            ),
          ),
          // Loading indicator below logo
          Positioned(
            top: MediaQuery.of(context).size.height * 0.30 + 120,
            left: 0,
            right: 0,
            child: const Center(
              child: DDLoadingIndicator(size: DDLoadingSize.lg),
            ),
          ),
        ],
      ),
    );
  }
}
