import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_text_field.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

/// /settings/account — Account settings.
/// Display name (tappable), email (read-only), appearance selector, sign out.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final themeMode = ref.watch(themeModeProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final isEmailVerified = firebaseUser?.emailVerified ?? true;

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Account', style: DDTypography.h3),
      ),
      body: ListView(
        children: [
          // Email verification banner
          if (!isEmailVerified) ...[
            Container(
              width: double.infinity,
              color: DDColors.amber.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(
                horizontal: DDSpacing.xl,
                vertical: DDSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: DDColors.warning),
                  const SizedBox(width: DDSpacing.sm),
                  Expanded(
                    child: Text(
                      'Please verify your email address.',
                      style: DDTypography.caption
                          .copyWith(color: DDColors.warning),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await firebaseUser?.sendEmailVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification email sent.'),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: DDColors.hunterGreen,
                    ),
                    child: Text('Resend', style: DDTypography.caption.copyWith(
                      color: DDColors.hunterGreen,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ],
              ),
            ),
          ],
          // Display name row — tappable
          InkWell(
            onTap: () =>
                _editDisplayName(context, ref, user?.displayName ?? ''),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DDSpacing.xl,
                vertical: DDSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display Name',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.displayName ?? '—',
                          style: DDTypography.bodyM,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: DDColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
          // Email row — read-only
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DDSpacing.xl,
              vertical: DDSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style:
                      DDTypography.caption.copyWith(color: DDColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(user?.email ?? '—', style: DDTypography.bodyM),
              ],
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
          // Appearance row — tappable
          InkWell(
            onTap: () => _pickTheme(context, ref, themeMode),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DDSpacing.xl,
                vertical: DDSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(_themeModeLabel(themeMode),
                            style: DDTypography.bodyM),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: DDColors.textMuted),
                ],
              ),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
          // About row
          InkWell(
            onTap: () => context.push(Routes.about),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DDSpacing.xl,
                vertical: DDSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('About', style: DDTypography.bodyM)),
                  const Icon(Icons.chevron_right, size: 20, color: DDColors.textMuted),
                ],
              ),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
          const SizedBox(height: DDSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
            child: DDButton.destructive(
              label: 'Sign Out',
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
                context.go(Routes.login);
              },
            ),
          ),
          const SizedBox(height: DDSpacing.xxl),
          Center(
            child: Text(
              'App version 1.0.0',
              style: DDTypography.caption.copyWith(color: DDColors.textMuted),
            ),
          ),
          const SizedBox(height: DDSpacing.lg),
        ],
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _editDisplayName(
      BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    DDBottomSheet.show(
      context: context,
      title: 'Edit Display Name',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DDTextField(
            label: 'Display Name',
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: DDSpacing.lg),
          DDButton.primary(
            label: 'Save',
            onPressed: () async {
              final name = ctrl.text.trim();
              Navigator.of(context).pop();
              if (name.isEmpty) return;
              try {
                await FirebaseAuth.instance.currentUser
                    ?.updateDisplayName(name);
              } catch (_) {
                // Non-fatal — display name update best-effort
              }
            },
          ),
        ],
      ),
    );
  }

  void _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    DDBottomSheet.show(
      context: context,
      title: 'Appearance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: modes
            .map(
              (mode) => ListTile(
                title: Text(_themeModeLabel(mode), style: DDTypography.bodyM),
                trailing: mode == current
                    ? const Icon(Icons.check, color: DDColors.hunterGreen)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).state = mode;
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
      ),
    );
  }
}
