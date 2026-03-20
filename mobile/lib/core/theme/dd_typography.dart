import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dd_colors.dart';

/// DingDong typography scale — Inter font via google_fonts
/// Per PRD Section 5.4
abstract final class DDTypography {
  /// Display — 32sp, Inter 700, letterSpacing -0.5, lineHeight 1.2
  /// Used on splash, hero screens
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: DDColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  /// H1 — 24sp, Inter 700, letterSpacing -0.3, lineHeight 1.3
  /// Used for screen titles
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: DDColors.textPrimary,
        height: 1.3,
        letterSpacing: -0.3,
      );

  /// H2 — 20sp, Inter 600, letterSpacing -0.2, lineHeight 1.35
  /// Used for section headers
  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.35,
        letterSpacing: -0.2,
      );

  /// H3 — 17sp, Inter 600, letterSpacing 0, lineHeight 1.4
  /// Used for card titles
  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.4,
      );

  /// Body L — 16sp, Inter 400, lineHeight 1.6
  /// Primary body text
  static TextStyle get bodyL => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: DDColors.textPrimary,
        height: 1.6,
      );

  /// Body M — 14sp, Inter 400, lineHeight 1.5
  /// List items, descriptions
  static TextStyle get bodyM => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: DDColors.textPrimary,
        height: 1.5,
      );

  /// Caption — 12sp, Inter 400, letterSpacing 0.2, lineHeight 1.4
  /// Timestamps, metadata
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: DDColors.textMuted,
        height: 1.4,
        letterSpacing: 0.2,
      );

  /// Label — 13sp, Inter 500, letterSpacing 0.1, lineHeight 1.0
  /// Buttons, chips, badges
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: DDColors.textPrimary,
        height: 1.0,
        letterSpacing: 0.1,
      );

  /// Mono — 13sp JetBrains Mono 400
  /// Device IDs, tokens, debug screen
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: DDColors.textPrimary,
      );
}
