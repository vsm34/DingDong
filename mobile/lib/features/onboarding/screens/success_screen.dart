import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /onboard/success — Step 5/5
/// Lottie checkmark (120px), device name field, "Start Monitoring" button.
/// Subtle confetti Lottie behind content.
class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen> {
  final _nameCtrl = TextEditingController(text: 'Front Door');

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingProvider.notifier).setDeviceName(_nameCtrl.text.trim());
    ref.read(onboardingProvider.notifier).reset();
    context.go(Routes.homeEvents);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Confetti background
            Positioned.fill(
              child: Lottie.asset(
                'assets/lottie/confetti.json',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: DDSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('5 of 5', style: DDTypography.caption),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/lottie/checkmark.json',
                      repeat: false,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: DDColors.hunterGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: DDSpacing.lg),
                  Text(
                    'DingDong is Ready!',
                    style: DDTypography.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DDSpacing.sm),
                  Text(
                    'Give your device a name.',
                    style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DDSpacing.lg),
                  DDTextField(
                    label: 'Device name',
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _finish(),
                    onChanged: (v) =>
                        ref.read(onboardingProvider.notifier).setDeviceName(v),
                  ),
                  const Spacer(),
                  DDButton.primary(
                    label: 'Start Monitoring',
                    onPressed: _finish,
                  ),
                  const SizedBox(height: DDSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
