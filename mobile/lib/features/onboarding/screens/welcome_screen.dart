import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../navigation/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.navyPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: DDColors.electricBlue,
                  borderRadius: BorderRadius.circular(DDSpacing.radiusXl),
                ),
                child: const Icon(Icons.doorbell_outlined,
                    color: DDColors.white, size: 56),
              ),
              const SizedBox(height: DDSpacing.xl),
              Text(
                'Set Up Your\nDingDong',
                style: DDTypography.display
                    .copyWith(color: DDColors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DDSpacing.md),
              Text(
                'Let\'s connect your smart doorbell\nto your home Wi-Fi in just a few steps.',
                style: DDTypography.bodyLg
                    .copyWith(color: DDColors.textOnDarkSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const _StepIndicator(steps: 5, current: 0),
              const SizedBox(height: DDSpacing.xl),
              DDButton.primary(
                label: 'Get Started',
                onPressed: () => context.go(Routes.onboardConnectAp),
              ),
              const SizedBox(height: DDSpacing.md),
              DDButton.ghost(
                label: 'I already have an account',
                onPressed: () => context.go(Routes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int steps;
  final int current;

  const _StepIndicator({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps, (i) {
        final active = i == current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: DDSpacing.xs),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                active ? DDColors.electricBlue : DDColors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
          ),
        );
      }),
    );
  }
}
