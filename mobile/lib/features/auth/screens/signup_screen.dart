import 'dart:ui';
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

/// /signup — Same full-bleed background as login. BackdropFilter sigmaX:3, sigmaY:3.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;


  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signUp(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _nameCtrl.text.trim(),
          );
      if (mounted) context.go(Routes.homeEvents);
    } catch (_) {
      if (mounted) {
        DDToast.error(context, 'Account creation failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          Image.asset(
            'assets/images/patio.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // Dark overlay
          Container(color: Colors.black.withValues(alpha: 0.30)),
          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // White logo — slightly larger on signup
                  const DDLogo.white(showWordmark: true),
                  const SizedBox(height: 36),
                  // Frosted glass card — sigmaX:3, sigmaY:3
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create account', style: DDTypography.h1),
                              const SizedBox(height: DDSpacing.sm),
                              Text(
                                'Start protecting your home today',
                                style: DDTypography.bodyM
                                    .copyWith(color: DDColors.textMuted),
                              ),
                              const SizedBox(height: DDSpacing.xl),
                              DDTextField(
                                label: 'Display Name',
                                hint: 'Your name',
                                controller: _nameCtrl,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: DDSpacing.md),
                              DDTextField(
                                label: 'Email',
                                hint: 'you@example.com',
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Email is required';
                                  }
                                  final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!re.hasMatch(v)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: DDSpacing.md),
                              DDTextField(
                                label: 'Password',
                                controller: _passwordCtrl,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: DDSpacing.md),
                              DDTextField(
                                label: 'Confirm Password',
                                controller: _confirmCtrl,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _createAccount(),
                                validator: (v) {
                                  if (v != _passwordCtrl.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: DDSpacing.lg),
                              DDButton.primary(
                                label: 'Create Account',
                                onPressed: _isLoading ? null : _createAccount,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DDSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: DDTypography.bodyM.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Sign in',
                          style: DDTypography.bodyM.copyWith(
                            color: DDColors.hunterGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          // Unsplash credit
          Positioned(
            bottom: 8,
            right: 12,
            child: Text(
              'Photo by Stephan Bechert on Unsplash',
              style: DDTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
