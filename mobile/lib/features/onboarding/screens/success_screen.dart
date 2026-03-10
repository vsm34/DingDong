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

/// /onboard/success — Device connected. User names the device.
class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen> {
  final _nameCtrl = TextEditingController(text: 'Front Door');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardingProvider.notifier).setDeviceName(_nameCtrl.text.trim());
    ref.read(onboardingProvider.notifier).reset();
    context.go(Routes.homeEvents);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: DDColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 44, color: DDColors.white),
                ),
                const SizedBox(height: DDSpacing.lg),
                Text('Device Connected!',
                    style: DDTypography.display, textAlign: TextAlign.center),
                const SizedBox(height: DDSpacing.sm),
                Text(
                  'Your DingDong is online and ready.\nGive it a name to finish setup.',
                  style:
                      DDTypography.body.copyWith(color: DDColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                DDTextField(
                  label: 'Device Name',
                  hint: 'e.g. Front Door',
                  controller: _nameCtrl,
                  maxLength: 32,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _finish(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Device name is required';
                    }
                    if (v.trim().length > 32) {
                      return 'Name must be 32 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.xl),
                DDButton.primary(
                  label: 'Finish Setup',
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
