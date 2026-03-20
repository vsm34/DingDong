import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../components/dd_logo.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /login — White background.
/// Logo small centered at top (80px from safe area).
/// H1 "Welcome back". Body M muted "Sign in to your account".
/// DDTextField email + password. "Forgot password?" right-aligned.
/// DDButton primary "Sign In". "Don't have an account? Sign up" link.
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
      backgroundColor: DDColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.xl,
            vertical: DDSpacing.md,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 80px from safe area top
                const SizedBox(height: 80),
                // Logo small centered
                const Center(child: DDLogo.appBar(showWordmark: true)),
                const SizedBox(height: DDSpacing.xxl),
                // H1 "Welcome back"
                Text('Welcome back', style: DDTypography.h1),
                const SizedBox(height: DDSpacing.sm),
                // Body M muted
                Text(
                  'Sign in to your account',
                  style: DDTypography.bodyM
                      .copyWith(color: DDColors.textMuted),
                ),
                const SizedBox(height: DDSpacing.xl),
                // Email field
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
                // Password field
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
                const SizedBox(height: DDSpacing.sm),
                // Forgot password — right-aligned
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: DDTypography.bodyM
                          .copyWith(color: DDColors.hunterGreen),
                    ),
                  ),
                ),
                const SizedBox(height: DDSpacing.lg),
                // Sign In button
                DDButton.primary(
                  label: 'Sign In',
                  onPressed: _isLoading ? null : _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: DDSpacing.md),
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: DDTypography.bodyM
                          .copyWith(color: DDColors.textMuted),
                    ),
                    GestureDetector(
                      onTap: () => context.push(Routes.signup),
                      child: Text(
                        'Sign up',
                        style: DDTypography.bodyM.copyWith(
                          color: DDColors.hunterGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
