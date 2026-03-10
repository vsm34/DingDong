import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../navigation/app_router.dart';

/// /onboard/connect-ap — Instruct user to connect phone to DingDong-Setup AP
class ConnectApScreen extends StatelessWidget {
  const ConnectApScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.surface,
      appBar: AppBar(
        title: const Text('Connect to Device'),
        leading: BackButton(onPressed: () => context.go(Routes.onboardWelcome)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Step(number: 1, label: 'Plug in your DingDong'),
              const SizedBox(height: DDSpacing.xs),
              Text(
                'Connect the USB-C cable and wait for the LED to turn solid white (~10 seconds).',
                style:
                    DDTypography.body.copyWith(color: DDColors.textSecondary),
              ),
              const SizedBox(height: DDSpacing.lg),
              const _Step(number: 2, label: 'Connect to DingDong Wi-Fi'),
              const SizedBox(height: DDSpacing.xs),
              Text(
                'Open your phone\'s Wi-Fi settings and connect to:',
                style:
                    DDTypography.body.copyWith(color: DDColors.textSecondary),
              ),
              const SizedBox(height: DDSpacing.sm),
              DDCard(
                backgroundColor: DDColors.navyPrimary.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    const Icon(Icons.wifi,
                        color: DDColors.navyPrimary, size: 20),
                    const SizedBox(width: DDSpacing.sm),
                    Text('DingDong-Setup',
                        style: DDTypography.labelLg
                            .copyWith(color: DDColors.navyPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: DDSpacing.lg),
              DDCard(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: DDColors.electricBlue, size: 20),
                    const SizedBox(width: DDSpacing.sm),
                    Expanded(
                      child: Text(
                        'Your internet will be disconnected briefly while you\'re connected to the device.',
                        style: DDTypography.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              DDButton.primary(
                label: 'I\'m connected to DingDong-Setup',
                onPressed: () => context.go(Routes.onboardProvisioning),
              ),
              const SizedBox(height: DDSpacing.sm),
              DDButton.ghost(
                label: 'Back',
                onPressed: () => context.go(Routes.onboardWelcome),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String label;

  const _Step({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: DDColors.navyPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: DDTypography.captionBold.copyWith(color: DDColors.white),
            ),
          ),
        ),
        const SizedBox(width: DDSpacing.sm),
        Text(label, style: DDTypography.h3),
      ],
    );
  }
}
