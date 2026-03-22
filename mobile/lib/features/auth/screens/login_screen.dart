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

/// /login — Full-bleed Unsplash background, dark overlay, floating frosted card.
/// White inverted logo + tagline above card. Unsplash credit at bottom.
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
      backgroundColor: DDColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          Image.asset(
            'assets/images/patio.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay
          Container(color: Colors.black.withValues(alpha: 0.45)),
          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  // White logo
                  const DDLogo.white(showWordmark: true),
                  const SizedBox(height: 12),
                  // Tagline
                  Text(
                    'Front door intelligence.',
                    style: DDTypography.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Frosted glass card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
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
                              Text('Welcome back', style: DDTypography.h1),
                              const SizedBox(height: DDSpacing.sm),
                              Text(
                                'Sign in to your account',
                                style: DDTypography.bodyM
                                    .copyWith(color: DDColors.textMuted),
                              ),
                              const SizedBox(height: DDSpacing.xl),
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
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: DDTypography.bodyM
                                        .copyWith(color: DDColors.hunterGreen),
                                  ),
                                ),
                              ),
                              const SizedBox(height: DDSpacing.lg),
                              DDButton.primary(
                                label: 'Sign In',
                                onPressed: _isLoading ? null : _signIn,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DDSpacing.lg),
                  // Sign up link — white text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: DDTypography.bodyM.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
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
                  const SizedBox(height: 80),
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
