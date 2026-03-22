import 'package:flutter/material.dart';
import '../core/theme/dd_colors.dart';

/// A small status dot that pulses when [isOnline] is true.
/// Online: green pulsing dot (scale 0.85→1.0, 2s repeat, easeInOut).
/// Offline: static red dot.
class PulsingDot extends StatefulWidget {
  final bool isOnline;
  final double size;

  const PulsingDot({
    super.key,
    required this.isOnline,
    this.size = 7,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) _startPulse();
  }

  @override
  void didUpdateWidget(PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && _ctrl == null) {
      _startPulse();
    } else if (!widget.isOnline && _ctrl != null) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl!, curve: Curves.easeInOut),
    );
    _ctrl!.repeat(reverse: true);
    setState(() {});
  }

  void _stopPulse() {
    _ctrl?.dispose();
    _ctrl = null;
    _scale = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? DDColors.online : DDColors.error;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (widget.isOnline && _scale != null) {
      return ScaleTransition(scale: _scale!, child: dot);
    }
    return dot;
  }
}
