import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /splash — shown briefly while app initializes
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
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
      backgroundColor: DDColors.navyPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: DDColors.electricBlue,
                borderRadius: BorderRadius.circular(DDSpacing.radiusXl),
              ),
              child: const Icon(
                Icons.doorbell_outlined,
                color: DDColors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: DDSpacing.md),
            Text(
              'DingDong',
              style: DDTypography.display.copyWith(color: DDColors.white),
            ),
            const SizedBox(height: DDSpacing.xs),
            Text(
              'Smart Doorbell',
              style: DDTypography.body
                  .copyWith(color: DDColors.textOnDarkSecondary),
            ),
            const SizedBox(height: DDSpacing.xxxl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: DDColors.electricBlueLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
