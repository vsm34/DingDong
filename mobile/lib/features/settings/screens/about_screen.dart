import 'package:flutter/material.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_logo.dart';

/// /settings/about — About screen.
/// DingDong logo, version, tagline, team credits, advisor, course info.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text('About', style: DDTypography.h3),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
                children: [
                  const SizedBox(height: DDSpacing.xxl),
                  const Center(child: DDLogo.hero()),
                  const SizedBox(height: DDSpacing.lg),
                  Center(
                    child: Text(
                      'Version 1.0.0',
                      style: DDTypography.caption
                          .copyWith(color: DDColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: DDSpacing.sm),
                  Center(
                    child: Text(
                      'Front door intelligence.',
                      style: DDTypography.bodyM.copyWith(
                        color: DDColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: DDSpacing.xl),
                  const Divider(
                      height: 0.5, thickness: 0.5, color: DDColors.borderDefault),
                  const SizedBox(height: DDSpacing.lg),
                  Text(
                    'Built by',
                    style: DDTypography.caption.copyWith(
                      color: DDColors.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: DDSpacing.sm),
                  Text('Gian Rosario', style: DDTypography.bodyM),
                  const SizedBox(height: DDSpacing.xs),
                  Text('Vini Silva', style: DDTypography.bodyM),
                  const SizedBox(height: DDSpacing.xs),
                  Text('Varun Mantha', style: DDTypography.bodyM),
                  const SizedBox(height: DDSpacing.lg),
                  Text(
                    'Advisor: Dov Kruger',
                    style: DDTypography.caption.copyWith(color: DDColors.textMuted),
                  ),
                  const SizedBox(height: DDSpacing.sm),
                  Text(
                    'SP26-41 · Rutgers University · Spring 2026',
                    style: DDTypography.caption.copyWith(color: DDColors.textMuted),
                  ),
                  const SizedBox(height: DDSpacing.xl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: DDSpacing.xl),
              child: Text(
                'Built with privacy in mind',
                style: DDTypography.caption.copyWith(
                  color: DDColors.hunterGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
