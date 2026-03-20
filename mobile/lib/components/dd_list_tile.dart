import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDListTile — per PRD Section 5.6
/// height: 64px minimum, padding: 12px horizontal
/// Leading icon area: 40x40px, radius sm, colored bg per event type
/// Title: Body M, #1A2E1A, font-weight 600
/// Subtitle: Caption, #6B7280
/// Separator: 0.5px #E0E0DC, inset 16px left
class DDListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final EdgeInsetsGeometry? contentPadding;

  const DDListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: contentPadding ??
                  const EdgeInsets.symmetric(
                    horizontal: DDSpacing.listTilePaddingH,
                    vertical: DDSpacing.listTilePaddingV,
                  ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: DDSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: DDTypography.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DDColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: DDTypography.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: DDSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: DDSpacing.listTilePaddingH,
            endIndent: 0,
            color: DDColors.borderDefault,
          ),
      ],
    );
  }
}

/// DDSettingsTile — settings rows with label, description, and a trailing control
class DDSettingsTile extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DDSettingsTile({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.listTilePaddingH,
            vertical: DDSpacing.listTilePaddingV,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: leading!),
                ),
                const SizedBox(width: DDSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: DDTypography.bodyM.copyWith(
                        fontWeight: FontWeight.w500,
                        color: DDColors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: DDTypography.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: DDColors.textDisabled,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
