import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../navigation/app_router.dart';

/// /onboard/connect-ap — Step 2/5
/// Step indicator, 3 numbered DDCard instruction rows, "I'm Connected" button.
class ConnectApScreen extends StatelessWidget {
  const ConnectApScreen({super.key});

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
          onPressed: () => context.go(Routes.onboardWelcome),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: Text('2 of 5', style: DDTypography.caption),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DDSpacing.xl),
              Text('Connect to DingDong', style: DDTypography.h2),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'Follow these steps to put your device in setup mode.',
                style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              ),
              const SizedBox(height: DDSpacing.xl),
              const _InstructionCard(
                step: '1',
                text: 'Plug in your DingDong device',
                icon: Icons.power,
              ),
              const SizedBox(height: DDSpacing.md),
              const _InstructionCard(
                step: '2',
                text: 'Wait for the LED to blink',
                icon: Icons.lightbulb_outline,
              ),
              const SizedBox(height: DDSpacing.md),
              const _InstructionCard(
                step: '3',
                text: 'Go to Wi-Fi settings → connect to DingDong-Setup',
                icon: Icons.wifi,
              ),
              const Spacer(),
              DDButton.primary(
                label: "I'm Connected",
                onPressed: () => context.go(Routes.onboardProvisioning),
              ),
              const SizedBox(height: DDSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String step;
  final String text;
  final IconData icon;

  const _InstructionCard({
    required this.step,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DDCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DDColors.hunterGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: DDTypography.label.copyWith(
                  color: DDColors.hunterGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: DDSpacing.md),
          Expanded(
            child: Text(text, style: DDTypography.bodyM),
          ),
          Icon(icon, size: 20, color: DDColors.textMuted),
        ],
      ),
    );
  }
}
