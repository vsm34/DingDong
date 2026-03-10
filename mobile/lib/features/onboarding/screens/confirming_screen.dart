import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../navigation/app_router.dart';

/// /onboard/confirming — Polls for device connection status
class ConfirmingScreen extends ConsumerStatefulWidget {
  const ConfirmingScreen({super.key});

  @override
  ConsumerState<ConfirmingScreen> createState() => _ConfirmingScreenState();
}

class _ConfirmingScreenState extends ConsumerState<ConfirmingScreen> {
  @override
  void initState() {
    super.initState();
    _waitForConfirmation();
  }

  Future<void> _waitForConfirmation() async {
    // In mock mode, simulate polling delay then navigate to success
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) context.go(Routes.onboardSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: DDColors.electricBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_find_outlined,
                      size: 40, color: DDColors.electricBlue),
                ),
                const SizedBox(height: DDSpacing.lg),
                Text('Connecting to your Wi-Fi…', style: DDTypography.h2,
                    textAlign: TextAlign.center),
                const SizedBox(height: DDSpacing.sm),
                Text(
                  'Your DingDong is connecting to your\nhome Wi-Fi. This takes about 15 seconds.',
                  style:
                      DDTypography.body.copyWith(color: DDColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DDSpacing.xl),
                const DDLoadingIndicator(
                  message: 'Waiting for device response…',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
