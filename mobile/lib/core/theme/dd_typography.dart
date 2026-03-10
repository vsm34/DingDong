import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dd_colors.dart';

/// DingDong typography scale — Inter font
abstract final class DDTypography {
  // Display
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: DDColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  // Headlines
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: DDColors.textPrimary,
        height: 1.3,
        letterSpacing: -0.3,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.4,
      );

  // Body
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: DDColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: DDColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: DDColors.textSecondary,
        height: 1.5,
      );

  // Labels
  static TextStyle get labelLg => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: DDColors.textPrimary,
        height: 1.4,
        letterSpacing: 0.1,
      );

  // Caption
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: DDColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get captionBold => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: DDColors.textSecondary,
        height: 1.4,
        letterSpacing: 0.2,
      );

  // Button text
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonSm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );
}
