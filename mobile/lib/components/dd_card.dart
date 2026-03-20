import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';

/// DDCard — per PRD Section 5.6
/// background: #FFFFFF, border: 0.5px #E0E0DC, radius: md (8px)
/// padding: 16px, shadow: 0 1px 3px rgba(0,0,0,0.06)
/// Motion event card: background #F4F6F1
/// Doorbell event card: background #FFFBEB
class DDCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;
  final bool hasShadow;

  const DDCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.hasShadow = true,
  });

  const DDCard.motion({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.hasShadow = true,
  }) : backgroundColor = DDColors.motionEventBg;

  const DDCard.doorbell({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.hasShadow = true,
  }) : backgroundColor = DDColors.doorbellEventBg;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DDSpacing.radiusMd;
    final bg = backgroundColor ?? DDColors.white;

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: DDColors.borderDefault, width: 0.5),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );

    final content = Container(
      decoration: decoration,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DDSpacing.cardPadding),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}
