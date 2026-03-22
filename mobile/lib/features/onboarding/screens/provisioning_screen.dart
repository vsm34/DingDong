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

/// /onboard/provisioning — Step 3/5
/// SSID + Password fields, privacy caption, "Connect Device" button.
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _connectDevice() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardingProvider.notifier).setWifiSsid(_ssidCtrl.text.trim());
    context.go(Routes.onboardConfirming);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: DDSpacing.md),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go(Routes.onboardConnectAp),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: DDColors.hunterGreen,
                      ),
                      label: Text(
                        'Back',
                        style: DDTypography.bodyM
                            .copyWith(color: DDColors.hunterGreen),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    const Spacer(),
                    Text('3 of 5', style: DDTypography.caption),
                  ],
                ),
                const SizedBox(height: DDSpacing.xl),
                Text('Connect to home Wi-Fi', style: DDTypography.h2),
                const SizedBox(height: DDSpacing.sm),
                Text(
                  'Enter your home Wi-Fi credentials.',
                  style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
                ),
                const SizedBox(height: DDSpacing.md),
                // 2.4 GHz warning
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSpacing.md,
                    vertical: DDSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: DDColors.amber.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(DDSpacing.radiusMd),
                    border: Border.all(
                        color: DDColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: DDColors.warning),
                      const SizedBox(width: DDSpacing.sm),
                      Expanded(
                        child: Text(
                          'DingDong requires a 2.4 GHz Wi-Fi network. '
                          '5 GHz networks are not supported.',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DDSpacing.xl),
                DDTextField(
                  label: 'Wi-Fi Network (SSID)',
                  hint: 'My Home Network',
                  controller: _ssidCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'SSID is required';
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.md),
                DDTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _connectDevice(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.sm),
                Text(
                  'Your credentials are sent directly to the device and never stored in the cloud.',
                  style: DDTypography.caption
                      .copyWith(color: DDColors.textMuted),
                ),
                const Spacer(),
                DDButton.primary(
                  label: 'Connect Device',
                  onPressed: _connectDevice,
                ),
                const SizedBox(height: DDSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
