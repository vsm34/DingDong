import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../navigation/app_router.dart';

/// /onboard/connect-ap — Step 2/5
/// Step indicator, 3 numbered DDCard instruction rows, LED guide, "I'm Connected" button.
class ConnectApScreen extends StatelessWidget {
  const ConnectApScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => context.go(Routes.onboardWelcome),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: Text('2 of 5', style: DDTypography.caption),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DDSpacing.xl),
              Text('Connect to DingDong', style: DDTypography.h2),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'Follow these steps to put your device in setup mode.',
                style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              ),
              const SizedBox(height: DDSpacing.xl),
              const _InstructionCard(
                step: '1',
                text: 'Plug in your DingDong device',
                icon: Icons.power,
              ),
              const SizedBox(height: DDSpacing.md),
              const _InstructionCard(
                step: '2',
                text: 'Wait for the LED to blink blue',
                icon: Icons.lightbulb_outline,
              ),
              const SizedBox(height: DDSpacing.md),
              const _InstructionCard(
                step: '3',
                text: 'Keep this app open — it will find your device automatically.',
                icon: Icons.bluetooth_searching,
              ),
              const SizedBox(height: DDSpacing.xl),
              const _LedGuide(),
              const SizedBox(height: DDSpacing.xl),
              DDButton.primary(
                label: "I'm Connected",
                onPressed: () => context.go(Routes.onboardBleProvision),
              ),
              const SizedBox(height: DDSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String step;
  final String text;
  final IconData icon;

  const _InstructionCard({
    required this.step,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DDCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DDColors.hunterGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: DDTypography.label.copyWith(
                  color: DDColors.hunterGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: DDSpacing.md),
          Expanded(
            child: Text(text, style: DDTypography.bodyM),
          ),
          Icon(icon, size: 20, color: DDColors.textMuted),
        ],
      ),
    );
  }
}

/// Collapsible LED status guide.
class _LedGuide extends StatelessWidget {
  const _LedGuide();

  @override
  Widget build(BuildContext context) {
    return DDCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: DDSpacing.sm),
        title: Text(
          'What do the LED colors mean?',
          style: DDTypography.bodyM.copyWith(color: DDColors.textPrimary),
        ),
        iconColor: DDColors.hunterGreen,
        collapsedIconColor: DDColors.textMuted,
        children: const [
          _LedRow(
            color: Color(0xFFDC2626),
            label: 'Solid red — Device is booting',
            blink: false,
          ),
          SizedBox(height: DDSpacing.sm),
          _BlinkingLedRow(
            color: Color(0xFF3B82F6),
            label: 'Blinking blue — Ready to pair',
          ),
          SizedBox(height: DDSpacing.sm),
          _LedRow(
            color: Color(0xFF22C55E),
            label: 'Solid green — Connected to Wi-Fi',
            blink: false,
          ),
          SizedBox(height: DDSpacing.sm),
        ],
      ),
    );
  }
}

class _LedRow extends StatelessWidget {
  final Color color;
  final String label;
  final bool blink;

  const _LedRow({
    required this.color,
    required this.label,
    required this.blink,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: DDSpacing.md),
        Expanded(
          child: Text(label,
              style:
                  DDTypography.bodyM.copyWith(color: DDColors.textPrimary)),
        ),
      ],
    );
  }
}

class _BlinkingLedRow extends StatefulWidget {
  final Color color;
  final String label;

  const _BlinkingLedRow({required this.color, required this.label});

  @override
  State<_BlinkingLedRow> createState() => _BlinkingLedRowState();
}

class _BlinkingLedRowState extends State<_BlinkingLedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: DDSpacing.md),
        Expanded(
          child: Text(widget.label,
              style: DDTypography.bodyM
                  .copyWith(color: DDColors.textPrimary)),
        ),
      ],
    );
  }
}
