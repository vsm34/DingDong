import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_button.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /onboard/provisioning — User enters home Wi-Fi credentials, app sends to device
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController();
  final _wifiPassCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _wifiPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    ref.read(onboardingProvider.notifier).setWifiSsid(_ssidCtrl.text.trim());
    await ref.read(onboardingProvider.notifier).simulateProvisioning();
    if (mounted) context.go(Routes.onboardConfirming);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.surface,
      appBar: AppBar(
        title: const Text('Wi-Fi Setup'),
        leading: BackButton(onPressed: () => context.go(Routes.onboardConnectAp)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter your home Wi-Fi', style: DDTypography.h2),
                const SizedBox(height: DDSpacing.xs),
                Text(
                  'Your DingDong will connect to this network to send alerts.',
                  style: DDTypography.body
                      .copyWith(color: DDColors.textSecondary),
                ),
                const SizedBox(height: DDSpacing.xl),
                DDTextField(
                  label: 'Wi-Fi Network (SSID)',
                  hint: 'MyHomeNetwork',
                  controller: _ssidCtrl,
                  textInputAction: TextInputAction.next,
                  maxLength: 32,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'SSID is required';
                    if (v.length > 32) return 'SSID must be 32 characters or fewer';
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.md),
                DDTextField(
                  label: 'Wi-Fi Password',
                  hint: 'Leave blank for open networks',
                  controller: _wifiPassCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  maxLength: 63,
                  onSubmitted: (_) => _sendCredentials(),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length > 63) {
                      return 'Password must be 63 characters or fewer';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                DDButton.primary(
                  label: 'Send to Device',
                  onPressed: _isSending ? null : _sendCredentials,
                  isLoading: _isSending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
