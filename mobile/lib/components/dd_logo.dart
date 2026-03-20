import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/dd_colors.dart';

enum DDLogoSize { hero, appBar, icon }

/// DingDong logo — green bell with amber sound waves + wordmark
/// Per PRD Section 5.3
class DDLogo extends StatelessWidget {
  final DDLogoSize size;
  final bool showWordmark;
  final bool darkBackground;

  const DDLogo({
    super.key,
    this.size = DDLogoSize.hero,
    this.showWordmark = true,
    this.darkBackground = false,
  });

  const DDLogo.hero({super.key, this.showWordmark = true})
      : size = DDLogoSize.hero,
        darkBackground = false;

  const DDLogo.appBar({super.key, this.showWordmark = true})
      : size = DDLogoSize.appBar,
        darkBackground = false;

  const DDLogo.icon({super.key})
      : size = DDLogoSize.icon,
        showWordmark = false,
        darkBackground = false;

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case DDLogoSize.icon:
        return _buildIcon();
      case DDLogoSize.appBar:
        return _buildAppBarLogo();
      case DDLogoSize.hero:
        return _buildHeroLogo();
    }
  }

  Widget _buildIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const CustomPaint(
        size: Size(56, 56),
        painter: _BellPainter(bellHeight: 28, bellWidth: 30),
      ),
    );
  }

  Widget _buildAppBarLogo() {
    const bellH = 18.0;
    const bellW = 20.0;
    const waveSpan = 44.0;
    const totalWidth = waveSpan * 2 + bellW;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: totalWidth,
          height: bellH + 8,
          child: CustomPaint(
            painter: _LogoPainter(
              bellHeight: bellH,
              bellWidth: bellW,
              waveSpan: waveSpan,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 6),
          Text(
            'DingDong',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DDColors.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroLogo() {
    const bellH = 28.0;
    const bellW = 32.0;
    const waveSpan = 70.0;
    const totalWidth = waveSpan * 2 + bellW;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: totalWidth,
          height: bellH + 12,
          child: CustomPaint(
            painter: _LogoPainter(
              bellHeight: bellH,
              bellWidth: bellW,
              waveSpan: waveSpan,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 8),
          Text(
            'DingDong',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: DDColors.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ],
    );
  }
}

/// Paints just the bell (no waves) for the icon variant
class _BellPainter extends CustomPainter {
  final double bellHeight;
  final double bellWidth;

  const _BellPainter({required this.bellHeight, required this.bellWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    _drawBell(canvas, Offset(cx, cy), bellHeight, bellWidth);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints bell + amber sound waves on both sides
class _LogoPainter extends CustomPainter {
  final double bellHeight;
  final double bellWidth;
  final double waveSpan;

  const _LogoPainter({
    required this.bellHeight,
    required this.bellWidth,
    required this.waveSpan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bellCenter = Offset(size.width / 2, size.height / 2);

    // Draw waves left side (mirrored)
    canvas.save();
    canvas.scale(-1, 1);
    canvas.translate(-size.width, 0);
    _drawWaves(canvas, Offset(size.width / 2, size.height / 2), bellWidth, waveSpan);
    canvas.restore();

    // Draw waves right side
    _drawWaves(canvas, bellCenter, bellWidth, waveSpan);

    // Draw bell on top
    _drawBell(canvas, bellCenter, bellHeight, bellWidth);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _drawBell(Canvas canvas, Offset center, double h, double w) {
  final paint = Paint()..style = PaintingStyle.fill;
  const darkGreen = DDColors.hunterGreenDark;
  const green = DDColors.hunterGreen;

  // Bell body — wide trapezoid (wider at bottom than top)
  paint.color = green;
  final bodyPath = Path();
  final bodyTop = center.dy - h * 0.55;
  final bodyBottom = center.dy + h * 0.1;
  bodyPath.moveTo(center.dx - w * 0.25, bodyTop);
  bodyPath.lineTo(center.dx + w * 0.25, bodyTop);
  bodyPath.lineTo(center.dx + w * 0.5, bodyBottom);
  bodyPath.lineTo(center.dx - w * 0.5, bodyBottom);
  bodyPath.close();
  canvas.drawPath(bodyPath, paint);

  // Bell rim — wide flat rounded rect
  paint.color = darkGreen;
  final rimRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(center.dx, center.dy + h * 0.15),
      width: w + 4,
      height: h * 0.18,
    ),
    const Radius.circular(3),
  );
  canvas.drawRRect(rimRect, paint);

  // Bell clapper — circle beneath rim
  paint.color = darkGreen;
  canvas.drawCircle(
    Offset(center.dx, center.dy + h * 0.35),
    h * 0.1,
    paint,
  );

  // Bell stem — small rect + circle at top
  paint.color = green;
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(center.dx, center.dy - h * 0.6),
      width: h * 0.14,
      height: h * 0.16,
    ),
    paint,
  );
  canvas.drawCircle(
    Offset(center.dx, center.dy - h * 0.7),
    h * 0.09,
    paint,
  );
}

void _drawWaves(Canvas canvas, Offset center, double bellWidth, double waveSpan) {
  final arcStart = center.dx + bellWidth * 0.5;
  final opacities = [1.0, 0.75, 0.45, 0.20];
  final strokeWidths = [3.0, 2.5, 2.0, 1.5];
  final radiusFactors = [0.25, 0.45, 0.65, 0.85];

  for (var i = 0; i < 4; i++) {
    final paint = Paint()
      ..color = DDColors.amber.withValues(alpha: opacities[i])
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidths[i]
      ..strokeCap = StrokeCap.round;

    final radius = waveSpan * radiusFactors[i];
    final arcRect = Rect.fromCenter(
      center: Offset(arcStart, center.dy),
      width: radius * 2,
      height: radius * 2,
    );

    canvas.drawArc(
      arcRect,
      -math.pi * 0.4,
      math.pi * 0.8,
      false,
      paint,
    );
  }
}
