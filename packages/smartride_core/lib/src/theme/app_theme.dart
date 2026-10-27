import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData patient({bool dark = false}) =>
      _build(primary: kPatientPrimary, dark: dark, isDriver: false);

  static ThemeData driver({bool dark = false}) =>
      _build(primary: kDriverPrimary, dark: dark, isDriver: true);

  static ThemeData _build({
    required Color primary,
    required bool dark,
    required bool isDriver,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: dark ? Brightness.dark : Brightness.light,
      error: kError,
    ).copyWith(
      primary: primary,
      onPrimary: kOnPrimary,
      surface: dark ? kDarkSurface : kSurface,
      onSurface: dark ? kDarkText1 : kOnSurface,
      surfaceContainerHighest: dark ? kDarkSurface2 : kSurface2,
      outline: dark ? kDarkBorder : kBorder,
      // No Material tint over cards and sheets; elevation is shown with shadows.
      surfaceTint: Colors.transparent,
      // Tinted cards (Book a Ride, active ride), secondary text and grouped
      // rows, so screens never reach for light-only constants.
      primaryContainer: isDriver
          ? (dark ? kDarkBlueContainer : kBlue100)
          : (dark ? kDarkPatientContainer : kPatient100),
      onPrimaryContainer: isDriver
          ? (dark ? kDarkOnBlueContainer : kBlue800)
          : (dark ? kDarkOnPatientContainer : kPatient800),
      onSurfaceVariant: dark ? kDarkText2 : kText600,
      surfaceContainerLow: dark ? kDarkSurface2 : kCanvas,
      outlineVariant: dark ? kDarkBorder : kBorder,
    );

    final baseTextTheme =
        dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.dmSansTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: kFontDisplay,
        fontWeight: FontWeight.w800,
        color: dark ? kDarkText1 : kText900,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: kFontTitle,
        fontWeight: FontWeight.w700,
        color: dark ? kDarkText1 : kText900,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: kFontHeading,
        fontWeight: FontWeight.w700,
        color: dark ? kDarkText1 : kText900,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: kFontSubhead,
        fontWeight: FontWeight.w600,
        color: dark ? kDarkText1 : kText900,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: kFontBody,
        fontWeight: FontWeight.w400,
        color: dark ? kDarkText1 : kText900,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: kFontSmall,
        fontWeight: FontWeight.w400,
        color: dark ? kDarkText2 : kText600,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: kFontCaption,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: dark ? kDarkText2 : kText600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: dark ? kDarkBg : kCanvas,
      // iOS-style swipe-back on every platform.
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values)
          platform: const CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: kOnPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          color: kOnPrimary,
          fontSize: kFontSubhead,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: kOnPrimary,
          minimumSize: const Size(double.infinity, kButtonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLG),
          ),
          elevation: 0,
          textStyle: GoogleFonts.dmSans(
            fontSize: kFontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, kButtonHeight),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLG),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: kFontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.dmSans(
            fontSize: kFontSmall,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? kDarkSurface2 : kSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceLG,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
          borderSide: BorderSide(color: dark ? kDarkBorder : kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
          borderSide: BorderSide(color: dark ? kDarkBorder : kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
          borderSide: const BorderSide(color: kError),
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: kFontBody,
          color: dark ? kDarkText3 : kText400,
        ),
        labelStyle: GoogleFonts.dmSans(
          fontSize: kFontSmall,
          color: dark ? kDarkText2 : kText600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? kDarkSurface : kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusXL),
          side: BorderSide(
            color: dark ? kDarkBorder : kBorder,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: dark ? kDarkBorder : kBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? kDarkSurface : kSurface,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.dmSans(
            fontSize: kFontCaption,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? kDarkSurface : kSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(kRadiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? kDarkSurface : kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusXXL),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
        ),
        side: BorderSide(color: dark ? kDarkBorder : kBorder),
        backgroundColor: dark ? kDarkSurface2 : kSurface,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.dmSans(
          fontSize: kFontSmall,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
