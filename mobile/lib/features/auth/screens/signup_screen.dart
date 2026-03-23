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
import '../../../providers/providers.dart';

/// /signup — Same full-bleed background as login.
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
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static String _mapAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'too-many-requests':
        return 'Too many failed attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Account creation failed. Please try again.';
    }
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).signUp(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _nameCtrl.text.trim(),
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapAuthError(e.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Account creation failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  const SizedBox(height: 48),
                  // White logo — 10% smaller
                  Transform.scale(
                    scale: 0.9,
                    child: const DDLogo.white(showWordmark: true),
                  ),
                  const SizedBox(height: 36),
                  // Frosted glass card (web-safe)
                  _buildCard(
                    Form(
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
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
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
                            textInputAction: TextInputAction.next,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
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
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                            validator: (v) {
                              if (v != _passwordCtrl.text) {
                                return 'Passwords do not match';
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
