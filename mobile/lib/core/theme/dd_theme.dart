import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dd_colors.dart';
import 'dd_spacing.dart';

/// DDTheme — DingDong's centralized Material theme
abstract final class DDTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DDColors.navyPrimary,
        primary: DDColors.navyPrimary,
        secondary: DDColors.electricBlue,
        surface: DDColors.surface,
        error: DDColors.error,
        onPrimary: DDColors.white,
        onSecondary: DDColors.white,
        onSurface: DDColors.textPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: DDColors.surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w700, color: DDColors.textPrimary),
        headlineLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: DDColors.textPrimary),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600, color: DDColors.textPrimary),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: DDColors.textPrimary),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: DDColors.textPrimary),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: DDColors.textSecondary),
        labelLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: DDColors.white),
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: DDColors.navyPrimary,
        foregroundColor: DDColors.white,
        elevation: DDSpacing.elevationNone,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: DDColors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: DDColors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DDColors.white,
        indicatorColor: DDColors.electricBlue.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DDColors.navyPrimary);
          }
          return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: DDColors.textSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DDColors.navyPrimary, size: 24);
          }
          return const IconThemeData(color: DDColors.textSecondary, size: 24);
        }),
        elevation: DDSpacing.elevationSm,
        height: DDSpacing.bottomNavHeight,
        surfaceTintColor: Colors.transparent,
        shadowColor: DDColors.navyPrimary.withValues(alpha: 0.08),
      ),
      cardTheme: CardThemeData(
        color: DDColors.white,
        elevation: DDSpacing.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusLg),
          side: const BorderSide(color: DDColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DDColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md,
          vertical: DDSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.electricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error, width: 2),
        ),
        labelStyle:
            GoogleFonts.inter(fontSize: 14, color: DDColors.textSecondary),
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: DDColors.textDisabled),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: DDColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DDColors.navyPrimary,
          foregroundColor: DDColors.white,
          minimumSize: const Size(double.infinity, DDSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          elevation: DDSpacing.elevationNone,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DDColors.navyPrimary,
          minimumSize: const Size(double.infinity, DDSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          side: const BorderSide(color: DDColors.navyPrimary, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DDColors.electricBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DDColors.divider,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DDColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: DDColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(DDSpacing.md),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.white;
          return DDColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.electricBlue;
          return DDColors.surfaceVariant;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: DDColors.electricBlue,
        inactiveTrackColor: DDColors.surfaceVariant,
        thumbColor: DDColors.navyPrimary,
        overlayColor: DDColors.navyPrimary.withValues(alpha: 0.12),
        valueIndicatorColor: DDColors.navyPrimary,
        valueIndicatorTextStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: DDColors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DDColors.electricBlue,
        linearTrackColor: DDColors.surfaceVariant,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DDColors.white,
        modalBackgroundColor: DDColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(DDSpacing.radiusXl)),
        ),
        elevation: 0,
        modalElevation: 0,
      ),
    );
  }
}
