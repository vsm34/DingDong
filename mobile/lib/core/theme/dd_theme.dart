import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dd_colors.dart';
import 'dd_spacing.dart';

/// DDTheme — DingDong light-mode Material theme
/// Hunter green + amber palette. No blue anywhere.
abstract final class DDTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DDColors.hunterGreen,
        primary: DDColors.hunterGreen,
        secondary: DDColors.amber,
        surface: DDColors.white,
        error: DDColors.error,
        onPrimary: DDColors.white,
        onSecondary: DDColors.textPrimary,
        onSurface: DDColors.textPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: DDColors.white,
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
            fontSize: 12, fontWeight: FontWeight.w400, color: DDColors.textMuted),
        labelLarge: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500, color: DDColors.white),
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: DDColors.white,
        foregroundColor: DDColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: DDColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: DDColors.textPrimary),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DDColors.white,
        indicatorColor: DDColors.hunterGreen.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DDColors.hunterGreen);
          }
          return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: DDColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DDColors.hunterGreen, size: 24);
          }
          return const IconThemeData(color: DDColors.textMuted, size: 24);
        }),
        elevation: 0,
        height: DDSpacing.bottomNavHeight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: DDColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          side: const BorderSide(color: DDColors.borderDefault, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DDColors.softGreenGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md,
          vertical: DDSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.hunterGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: DDColors.textMuted),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: DDColors.textDisabled),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: DDColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DDColors.hunterGreen,
          foregroundColor: DDColors.white,
          minimumSize: const Size(double.infinity, DDSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DDColors.hunterGreen,
          minimumSize: const Size(double.infinity, DDSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          side: const BorderSide(color: DDColors.hunterGreen, width: 1),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DDColors.hunterGreen,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DDColors.borderDefault,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DDColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: DDColors.white),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(DDSpacing.md),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.white;
          return DDColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.hunterGreen;
          return DDColors.softGreenGray;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: DDColors.hunterGreen,
        inactiveTrackColor: DDColors.softGreenGray,
        thumbColor: DDColors.hunterGreen,
        overlayColor: DDColors.hunterGreen.withValues(alpha: 0.12),
        valueIndicatorColor: DDColors.hunterGreen,
        valueIndicatorTextStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: DDColors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DDColors.hunterGreen,
        linearTrackColor: DDColors.softGreenGray,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DDColors.white,
        modalBackgroundColor: DDColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(DDSpacing.radiusLg)),
        ),
        elevation: 0,
        modalElevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DDColors.softGreenGray,
        selectedColor: DDColors.hunterGreen,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DDColors.hunterGreen,
        primary: DDColors.hunterGreen,
        secondary: DDColors.amber,
        surface: DDColors.darkCard,
        error: DDColors.error,
        onPrimary: DDColors.white,
        onSecondary: DDColors.textPrimary,
        onSurface: DDColors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: DDColors.darkBg,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w700, color: DDColors.white),
        headlineLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: DDColors.white),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600, color: DDColors.white),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: DDColors.white),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: DDColors.white),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: DDColors.darkTextMuted),
        labelLarge: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500, color: DDColors.white),
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: DDColors.darkBg,
        foregroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: DDColors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: DDColors.white),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DDColors.darkCard,
        indicatorColor: DDColors.hunterGreen.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DDColors.hunterGreen);
          }
          return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: DDColors.darkTextMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DDColors.hunterGreen, size: 24);
          }
          return const IconThemeData(color: DDColors.darkTextMuted, size: 24);
        }),
        elevation: 0,
        height: DDSpacing.bottomNavHeight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: DDColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          side: const BorderSide(color: DDColors.darkBorder, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DDColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DDSpacing.md,
          vertical: DDSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.hunterGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          borderSide: const BorderSide(color: DDColors.error, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: DDColors.darkTextMuted),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: DDColors.darkTextMuted),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: DDColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DDColors.hunterGreen,
          foregroundColor: DDColors.white,
          minimumSize: const Size(double.infinity, DDSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DDSpacing.radiusMd),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DDColors.darkBorder,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DDColors.darkCard,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: DDColors.white),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(DDSpacing.md),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.white;
          return DDColors.darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return DDColors.hunterGreen;
          return DDColors.darkCard;
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DDColors.darkCard,
        modalBackgroundColor: DDColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(DDSpacing.radiusLg)),
        ),
        elevation: 0,
        modalElevation: 0,
      ),
    );
  }
}
