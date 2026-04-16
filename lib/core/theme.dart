import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand palette ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1C2128);
  static const Color primary = Color(0xFFE53935);
  static const Color secondary = Color(0xFFFF6D00);
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color border = Color(0xFF30363D);
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF3FB950);

  // ── Main theme ────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        surface: surface,
        primary: primary,
        secondary: secondary,
        onPrimary: textPrimary,
        onSurface: textPrimary,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.spaceGrotesk(color: textPrimary),
        bodyMedium: GoogleFonts.spaceGrotesk(color: textPrimary),
        bodySmall: GoogleFonts.spaceGrotesk(color: textSecondary),
        labelLarge: GoogleFonts.spaceGrotesk(color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.spaceGrotesk(color: textSecondary),
        labelSmall: GoogleFonts.spaceGrotesk(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.spaceGrotesk(color: textSecondary),
        hintStyle: GoogleFonts.spaceGrotesk(color: textSecondary),
        errorStyle: GoogleFonts.spaceGrotesk(color: error, fontSize: 12),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withAlpha(77),
          disabledForegroundColor: Colors.white54,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        textColor: textPrimary,
        iconColor: textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.spaceGrotesk(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
