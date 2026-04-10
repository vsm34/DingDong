import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_toast.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /onboard/confirming — Step 4/5
/// Lottie spinner (120px), auto-advances when provisioning completes.
/// Error state: shows troubleshooting DDBottomSheet with retry option.
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
    _showTroubleshootingSheet();
  }

  void _showTroubleshootingSheet() {
    DDBottomSheet.show<void>(
      context: context,
      title: 'Connection failed',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try these steps to reconnect:',
            style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
          ),
          const SizedBox(height: DDSpacing.md),
          ...[
            '1. Make sure your Wi-Fi password is correct',
            '2. Ensure you\'re connecting to a 2.4GHz network (not 5GHz)',
            '3. Move your phone closer to the router',
            '4. Try unplugging and replugging the DingDong device',
          ].map((step) => Padding(
                padding: const EdgeInsets.only(bottom: DDSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle,
                        size: 6,
                        color: DDColors.hunterGreen),
                    const SizedBox(width: DDSpacing.sm),
                    Expanded(
                      child: Text(step,
                          style: DDTypography.bodyM),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: DDSpacing.lg),
          DDButton.primary(
            label: 'Try Again',
            onPressed: () {
              Navigator.of(context).pop();
              _startProvisioning();
            },
          ),
          const SizedBox(height: DDSpacing.sm),
          DDButton.secondary(
            label: 'Contact Support',
            onPressed: () {
              Navigator.of(context).pop();
              DDToast.success(context, 'Visit dingdong.app/support for help');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => context.go(Routes.onboardBleProvision),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: Text('4 of 5', style: DDTypography.caption),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Column(
            children: [
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
                const SizedBox(height: DDSpacing.sm),
                DDButton.secondary(
                  label: 'Show Troubleshooting',
                  onPressed: _showTroubleshootingSheet,
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
