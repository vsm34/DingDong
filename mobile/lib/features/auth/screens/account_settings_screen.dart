import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_toast.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      backgroundColor: DDColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(DDSpacing.pagePadding),
          children: [
            // Profile card
            DDCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: DDColors.electricBlue,
                    child: Text(
                      (user?.displayName ?? 'U')[0].toUpperCase(),
                      style: DDTypography.h2
                          .copyWith(color: DDColors.white),
                    ),
                  ),
                  const SizedBox(width: DDSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? '—',
                            style: DDTypography.h3),
                        const SizedBox(height: DDSpacing.xs),
                        Text(user?.email ?? '—',
                            style: DDTypography.bodySm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DDSpacing.xl),
            DDCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(
                      label: 'Display Name',
                      value: user?.displayName ?? '—'),
                  const Divider(height: 1, indent: DDSpacing.md),
                  _InfoRow(label: 'Email', value: user?.email ?? '—'),
                  const Divider(height: 1, indent: DDSpacing.md),
                  _InfoRow(label: 'User ID', value: user?.uid ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: DDSpacing.xl),
            DDButton.destructive(
              label: 'Sign Out',
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
                context.go(Routes.login);
                DDToast.info(context, 'Signed out');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DDSpacing.md,
        vertical: DDSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  DDTypography.body.copyWith(color: DDColors.textSecondary)),
          Flexible(
            child: Text(value,
                style: DDTypography.body,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
