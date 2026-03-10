import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go(Routes.homeEvents);
    } catch (_) {
      if (mounted) DDToast.error(context, 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: DDSpacing.xxxl),
                // Brand mark
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: DDColors.navyPrimary,
                    borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.doorbell_outlined,
                      color: DDColors.white, size: 30),
                ),
                const SizedBox(height: DDSpacing.lg),
                Text('Welcome back', style: DDTypography.display),
                const SizedBox(height: DDSpacing.xs),
                Text(
                  'Sign in to your DingDong account',
                  style:
                      DDTypography.body.copyWith(color: DDColors.textSecondary),
                ),
                const SizedBox(height: DDSpacing.xl),
                DDTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!re.hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.md),
                DDTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DDSpacing.xl),
                DDButton.primary(
                  label: 'Sign In',
                  onPressed: _isLoading ? null : _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: DDSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: DDTypography.body
                            .copyWith(color: DDColors.textSecondary)),
                    TextButton(
                      onPressed: () => context.push(Routes.signup),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: DDSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        context.go(Routes.onboardWelcome),
                    child: Text(
                      'Set up a new device',
                      style: DDTypography.body
                          .copyWith(color: DDColors.electricBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
