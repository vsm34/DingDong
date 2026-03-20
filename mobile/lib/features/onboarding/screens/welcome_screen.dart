import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_logo.dart';
import '../../../navigation/app_router.dart';

/// /onboard/welcome — Step 1/5
/// Top half: hunter green hero block (50% height). Logo icon, "DingDong" display, caption.
/// Bottom half: white. H2, Body M, DDButton "Get Started", step dots.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: DDColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Hero — top ~45%
            SizedBox(
              height: screenHeight * 0.45,
              width: double.infinity,
              child: Container(
                color: DDColors.hunterGreen,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DDLogo.icon(),
                    const SizedBox(height: DDSpacing.md),
                    Text(
                      'DingDong',
                      style: DDTypography.display.copyWith(color: DDColors.white),
                    ),
                    const SizedBox(height: DDSpacing.sm),
                    Text(
                      'Smart Doorbell System',
                      style: DDTypography.caption.copyWith(
                        color: const Color(0xFFA7D4A7),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom — white
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    DDSpacing.xl, DDSpacing.lg, DDSpacing.xl, DDSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DDSpacing.md),
                    Text('Meet DingDong', style: DDTypography.h2),
                    const SizedBox(height: DDSpacing.sm),
                    Text(
                      'Privacy-first doorbell with local storage and smart alerts.',
                      style: DDTypography.bodyM.copyWith(color: DDColors.textSecondary),
                    ),
                    const Spacer(),
                    DDButton.primary(
                      label: 'Get Started',
                      onPressed: () => context.go(Routes.onboardConnectAp),
                    ),
                    const SizedBox(height: DDSpacing.lg),
                    const _StepDots(total: 5, current: 0),
                    const SizedBox(height: DDSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int total;
  final int current;

  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? DDColors.hunterGreen : Colors.transparent,
            border: Border.all(
              color: active ? DDColors.hunterGreen : DDColors.borderDefault,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(DDSpacing.radiusFull),
          ),
        );
      }),
    );
  }
}
