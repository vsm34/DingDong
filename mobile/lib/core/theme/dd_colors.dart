import 'package:flutter/material.dart';

/// DingDong brand color palette — hunter green + amber, no blue anywhere
abstract final class DDColors {
  // ── Primary brand ─────────────────────────────────────────────────────────
  static const Color hunterGreen = Color(0xFF355E3B);
  static const Color hunterGreenDark = Color(0xFF2A4D2F);
  static const Color amber = Color(0xFFF59E0B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color softGreenGray = Color(0xFFF4F6F1);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A2E1A);
  static const Color textSecondary = Color(0xFF4B6B4B);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color online = Color(0xFF166534);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ── Event surfaces ────────────────────────────────────────────────────────
  static const Color doorbellEventBg = Color(0xFFFFFBEB);
  static const Color doorbellEventChip = Color(0xFF92400E);
  static const Color motionEventBg = Color(0xFFF4F6F1);
  static const Color motionEventChip = Color(0xFF1C4532);
  static const Color clipAvailable = Color(0xFFD1FAE5);
  static const Color clipText = Color(0xFF065F46);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color borderDefault = Color(0xFFE0E0DC);
  static const Color borderStrong = Color(0xFFC8D8C8);
}
