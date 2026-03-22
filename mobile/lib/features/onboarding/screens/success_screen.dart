import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /onboard/success — Step 5/5
/// AnimatedScale checkmark icon (0→1, 400ms, elastic), device name field,
/// "Start Monitoring" button.
class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController(text: 'Front Door');
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: const ElasticOutCurve(0.6),
    );
    // Slight delay so screen is visible before the icon pops in
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _scaleCtrl.forward();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scaleCtrl.dispose();
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
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => context.go(Routes.onboardConfirming),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: Text('5 of 5', style: DDTypography.caption),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scaleAnim,
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: DDColors.hunterGreen,
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
      ),
    );
  }
}
