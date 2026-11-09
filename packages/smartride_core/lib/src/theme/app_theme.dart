import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Blue for text and outlines. The portal blue is 3.3:1 on the dark page,
    // so dark mode uses the lighter blue; filled buttons keep the portal blue.
    final link = dark ? kDarkAccent : primary;

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
      // An iOS navigation bar: the page colour, a centred title in ink, and
      // blue icons. Blue never fills the bar; it only marks what can be tapped.
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? kDarkBg : kCanvas,
        foregroundColor: dark ? kDarkText1 : kText900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: link),
        actionsIconTheme: IconThemeData(color: link),
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.dmSans(
          color: dark ? kDarkText1 : kText900,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      // The back arrow is the iOS chevron on every platform. It mirrors in
      // right-to-left languages such as Urdu.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
          foregroundColor: link,
          minimumSize: const Size(double.infinity, kButtonHeight),
          side: BorderSide(color: link, width: 1.5),
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
          foregroundColor: link,
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLG),
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
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
