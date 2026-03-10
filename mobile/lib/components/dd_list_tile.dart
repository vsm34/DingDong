import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDListTile — styled list item for events feed and clip list
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
                    children: [
                      Text(title, style: DDTypography.body),
                      if (subtitle != null) ...[
                        const SizedBox(height: DDSpacing.xs / 2),
                        Text(subtitle!, style: DDTypography.caption),
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
        if (showDivider)
          const Divider(
            height: 1,
            indent: DDSpacing.listTilePaddingH,
            endIndent: DDSpacing.listTilePaddingH,
          ),
      ],
    );
  }
}

/// DDSettingsTile — for settings rows with label, description, and a control widget
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.listTilePaddingH,
          vertical: DDSpacing.listTilePaddingV,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DDColors.electricBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DDSpacing.radiusSm),
                ),
                child: Center(child: leading!),
              ),
              const SizedBox(width: DDSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DDTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: DDColors.textPrimary,
                  )),
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
              const Icon(Icons.chevron_right,
                  color: DDColors.textDisabled, size: 20),
          ],
        ),
      ),
    );
  }
}
