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
/// Display name (tappable, edit DDBottomSheet), email (read-only).
/// "Sign Out" destructive button. "App version 1.0.0" caption at bottom.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text('Account', style: DDTypography.h3),
      ),
      body: ListView(
        children: [
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
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
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
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: DDColors.borderDefault,
          ),
          const SizedBox(height: DDSpacing.xl),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
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
            onPressed: () {
              // Phase 2B: persist to Firestore
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
