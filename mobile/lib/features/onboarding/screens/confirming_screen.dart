import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_toast.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /onboard/confirming — Step 4/5
/// Lottie spinner (120px), auto-advances when provisioning completes.
/// Error state: DDToast error + "Try Again" button if timeout > 60s.
class ConfirmingScreen extends ConsumerStatefulWidget {
  const ConfirmingScreen({super.key});

  @override
  ConsumerState<ConfirmingScreen> createState() => _ConfirmingScreenState();
}

class _ConfirmingScreenState extends ConsumerState<ConfirmingScreen> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startProvisioning();
  }

  Future<void> _startProvisioning() async {
    setState(() => _timedOut = false);
    try {
      await ref
          .read(onboardingProvider.notifier)
          .simulateProvisioning()
          .timeout(const Duration(seconds: 60));
      if (mounted) context.go(Routes.onboardSuccess);
    } on TimeoutException {
      if (mounted) _handleTimeout();
    } catch (_) {
      if (mounted) _handleTimeout();
    }
  }

  void _handleTimeout() {
    setState(() => _timedOut = true);
    DDToast.error(context, 'Connection timed out. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: DDSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('4 of 5', style: DDTypography.caption),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  'assets/lottie/connecting.json',
                  errorBuilder: (_, __, ___) => const CircularProgressIndicator(
                    color: DDColors.hunterGreen,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: DDSpacing.lg),
              Text(
                'Connecting your device...',
                style: DDTypography.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'This may take up to 30 seconds.',
                style: DDTypography.caption.copyWith(color: DDColors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (_timedOut) ...[
                const SizedBox(height: DDSpacing.xl),
                DDButton.primary(
                  label: 'Try Again',
                  onPressed: _startProvisioning,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
