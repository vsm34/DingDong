import 'package:flutter/material.dart';

/// DingDong brand color palette
abstract final class DDColors {
  // Primary brand
  static const Color navyPrimary = Color(0xFF1A3C5E);
  static const Color navyDark = Color(0xFF0F2438);
  static const Color navyLight = Color(0xFF2A4F75);

  // Accent
  static const Color electricBlue = Color(0xFF2E86C1);
  static const Color electricBlueLight = Color(0xFF5BAAD6);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color surfaceVariant = Color(0xFFEAEEF2);
  static const Color divider = Color(0xFFDDE5ED);

  // Text
  static const Color textPrimary = Color(0xFF0F1E2E);
  static const Color textSecondary = Color(0xFF4A6280);
  static const Color textDisabled = Color(0xFF9DB0C4);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFB8CCE0);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF2E86C1);

  // Status
  static const Color online = Color(0xFF27AE60);
  static const Color offline = Color(0xFFE74C3C);
  static const Color unknown = Color(0xFF9DB0C4);

  // Overlays
  static const Color scrim = Color(0x80000000);
  static const Color shimmerBase = Color(0xFFEAEEF2);
  static const Color shimmerHighlight = Color(0xFFF5F7FA);
}
