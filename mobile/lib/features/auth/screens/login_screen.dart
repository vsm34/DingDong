import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_logo.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';
import '../../../components/dd_bottom_sheet.dart';

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
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  static String _mapAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'too-many-requests':
        return 'Too many failed attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go(Routes.homeEvents);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapAuthError(e.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in failed. Please try again.';
        });
      }
    }
  }

  void _showPasswordReset(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    var isSending = false;
    DDBottomSheet.show(
      context: context,
      title: 'Reset Password',
      child: StatefulBuilder(
        builder: (ctx, setSS) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DDTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: DDSpacing.lg),
              DDButton.primary(
                label: 'Send Reset Link',
                isLoading: isSending,
                onPressed: isSending
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) return;
                        setSS(() => isSending = true);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .sendPasswordReset(email);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent.'),
                              ),
                            );
                          }
                        } catch (_) {
                          setSS(() => isSending = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to send reset email.'),
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(Widget child) {
    const radius = BorderRadius.all(Radius.circular(16));
    if (kIsWeb) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: radius,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
    );
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
                  const SizedBox(height: 64),
                  // White logo — 10% smaller
                  Transform.scale(
                    scale: 0.9,
                    child: const DDLogo.white(showWordmark: true),
                  ),
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
                  // Frosted glass card (web-safe)
                  _buildCard(
                    Form(
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
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
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
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errorMessage!,
                                style: DDTypography.caption.copyWith(
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          const SizedBox(height: DDSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showPasswordReset(context),
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
