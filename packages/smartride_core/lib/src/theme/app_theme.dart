import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData patient({bool dark = false}) =>
      _build(primary: kPatientPrimary, dark: dark);

  static ThemeData driver({bool dark = false}) =>
      _build(primary: kDriverPrimary, dark: dark);

  static ThemeData _build({required Color primary, required bool dark}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: dark ? Brightness.dark : Brightness.light,
      error: kError,
    ).copyWith(
      primary: primary,
      surface: dark ? const Color(0xFF121212) : kSurface,
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF121212) : kBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: kOnPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          color: kOnPrimary,
          fontSize: kFontLG,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: kOnPrimary,
          minimumSize: const Size(double.infinity, kMinTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLG),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: kFontMD,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMD),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceMD,
        ),
        filled: true,
        fillColor: dark ? const Color(0xFF1E1E1E) : kSurface,
      ),
      cardTheme: CardThemeData(
        elevation: kCardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

