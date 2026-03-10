import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

/// DDLoadingIndicator — branded loading spinner
class DDLoadingIndicator extends StatelessWidget {
  final String? message;
  final bool centerInScreen;

  const DDLoadingIndicator({
    super.key,
    this.message,
    this.centerInScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: DDColors.electricBlue,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: DDSpacing.md),
          Text(
            message!,
            style: DDTypography.body.copyWith(color: DDColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (centerInScreen) {
      return Center(child: content);
    }
    return content;
  }
}

/// Full-screen loading overlay
class DDLoadingOverlay extends StatelessWidget {
  final String? message;

  const DDLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DDColors.scrim,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(DDSpacing.xl),
          decoration: BoxDecoration(
            color: DDColors.white,
            borderRadius: BorderRadius.circular(DDSpacing.radiusLg),
          ),
          child: DDLoadingIndicator(message: message),
        ),
      ),
    );
  }
}

/// Inline shimmer row for list loading
class DDShimmerTile extends StatefulWidget {
  const DDShimmerTile({super.key});

  @override
  State<DDShimmerTile> createState() => _DDShimmerTileState();
}

class _DDShimmerTileState extends State<DDShimmerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.listTilePaddingH,
            vertical: DDSpacing.listTilePaddingV,
          ),
          child: Row(
            children: [
              _shimmerBox(40, 40, DDSpacing.radiusMd),
              const SizedBox(width: DDSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerLine(0.6),
                    const SizedBox(height: DDSpacing.xs),
                    _shimmerLine(0.4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerLine(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: DDColors.shimmerBase,
          borderRadius: BorderRadius.circular(DDSpacing.radiusXs),
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double radius) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: DDColors.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
