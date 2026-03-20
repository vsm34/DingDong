import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';
import '../core/theme/dd_spacing.dart';
import '../core/theme/dd_typography.dart';

enum DDLoadingSize { sm, md, lg }

/// DDLoadingIndicator — per PRD Section 5.6
/// Circular progress, color: #355E3B, strokeWidth: 2.5px
/// Sizes: sm 16px, md 24px, lg 40px
/// Full-screen loading: centered md indicator on white background with 300ms delay before showing
class DDLoadingIndicator extends StatelessWidget {
  final DDLoadingSize size;
  final String? message;
  final bool centerInScreen;

  const DDLoadingIndicator({
    super.key,
    this.size = DDLoadingSize.md,
    this.message,
    this.centerInScreen = false,
  });

  /// Convenience constructors matching legacy API
  const DDLoadingIndicator.sm({super.key, this.message})
      : size = DDLoadingSize.sm,
        centerInScreen = false;

  const DDLoadingIndicator.lg({super.key, this.message})
      : size = DDLoadingSize.lg,
        centerInScreen = false;

  static double _dimension(DDLoadingSize s) => switch (s) {
        DDLoadingSize.sm => 16.0,
        DDLoadingSize.md => 24.0,
        DDLoadingSize.lg => 40.0,
      };

  @override
  Widget build(BuildContext context) {
    final dim = _dimension(size);

    final indicator = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: dim,
          height: dim,
          child: const CircularProgressIndicator(
            color: DDColors.hunterGreen,
            strokeWidth: 2.5,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: DDSpacing.md),
          Text(
            message!,
            style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (centerInScreen) {
      return Scaffold(
        backgroundColor: DDColors.white,
        body: Center(child: indicator),
      );
    }
    return indicator;
  }
}

/// Full-screen loading with 300ms delay to prevent flash
class DDDelayedLoader extends StatefulWidget {
  final String? message;

  const DDDelayedLoader({super.key, this.message});

  @override
  State<DDDelayedLoader> createState() => _DDDelayedLoaderState();
}

class _DDDelayedLoaderState extends State<DDDelayedLoader> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Center(
      child: DDLoadingIndicator(
        size: DDLoadingSize.md,
        message: widget.message,
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
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
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
        final shimmer = Color.lerp(
          const Color(0xFFEEF0EC),
          const Color(0xFFF8F9F7),
          _animation.value,
        )!;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DDSpacing.md,
            vertical: DDSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
                ),
              ),
              const SizedBox(width: DDSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(DDSpacing.radiusSm),
                        ),
                      ),
                    ),
                    const SizedBox(height: DDSpacing.xs),
                    FractionallySizedBox(
                      widthFactor: 0.4,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(DDSpacing.radiusSm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
