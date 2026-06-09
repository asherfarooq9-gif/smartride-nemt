import 'package:flutter/material.dart';

// ── Patient portal — Teal ─────────────────────────────────────────────────────
const Color kTeal800 = Color(0xFF095F5F);
const Color kTeal600 = Color(0xFF0B7777); // primary
const Color kTeal400 = Color(0xFF0D9292);
const Color kTeal100 = Color(0xFFD8F0F0);
const Color kTeal50  = Color(0xFFEEF8F8);

const Color kPatientPrimary      = kTeal600;
const Color kPatientPrimaryLight = kTeal400;
const Color kPatientPrimaryDark  = kTeal800;

// ── Driver portal — Steel Blue ────────────────────────────────────────────────
const Color kBlue800 = Color(0xFF084A6E);
const Color kBlue600 = Color(0xFF0B5980); // driver primary
const Color kBlue100 = Color(0xFFD8ECF5);
const Color kBlueAccentDark = Color(0xFF4AADDB); // driver accent in dark mode

const Color kDriverPrimary      = kBlue600;
const Color kDriverPrimaryLight = Color(0xFF1A78A0);
const Color kDriverPrimaryDark  = kBlue800;

// ── Emergency — Red (RESERVED — never use for anything else) ──────────────────
const Color kRed800       = Color(0xFF9B1E1E);
const Color kRed600       = Color(0xFFC62828);
const Color kRed50        = Color(0xFFFFEBEE);
const Color kEmergencyRed = kRed600;
const Color kError        = kRed600;

// ── Neutrals — Light ─────────────────────────────────────────────────────────
const Color kText900      = Color(0xFF152626);
const Color kText600      = Color(0xFF4A6464);
const Color kText400      = Color(0xFF7A9494);
const Color kTextOff      = Color(0xFFAECBCB);
const Color kCanvas       = Color(0xFFECF7F7);
const Color kBorder       = Color(0xFFC8E2E2);
const Color kBorderLight  = Color(0xFFDAEEEE);
const Color kSurface      = Color(0xFFFFFFFF);
const Color kSurface2     = Color(0xFFF3FAFA);
const Color kBackground   = kCanvas;
const Color kOnPrimary    = Color(0xFFFFFFFF);
const Color kOnBackground = kText900;
const Color kOnSurface    = kText900;
const Color kTextSecondary = kText600;
const Color kDivider      = kBorder;

// ── Neutrals — Dark ──────────────────────────────────────────────────────────
const Color kDarkBg          = Color(0xFF0C1D1D);
const Color kDarkSurface     = Color(0xFF132424);
const Color kDarkSurface2    = Color(0xFF192C2C);
const Color kDarkBorder      = Color(0xFF254040);
const Color kDarkBorderLight = Color(0xFF1C3838);
const Color kDarkTeal        = Color(0xFF10BEBE);
const Color kDarkRed         = Color(0xFFEF5350);
const Color kDarkText1       = Color(0xFFE0F0F0);
const Color kDarkText2       = Color(0xFF80AAAA);
const Color kDarkText3       = Color(0xFF507070);

// ── Auth ──────────────────────────────────────────────────────────────────────
const Color kAuthDarkBg      = Color(0xFF0A1628);
const Color kAuthTeal        = kTeal600;
const Color kAuthTealDark    = kTeal800;
const Color kWelcomeGradStart = Color(0xFF0EABAB);
const Color kWelcomeGradMid   = kTeal600;
const Color kWelcomeGradEnd   = Color(0xFF084E4E);
const Color kDarkFieldBg     = Color(0xFF172136);
const Color kDarkFieldBorder = Color(0xFF2A3F5F);
const Color kEmergencyDarkBg = Color(0xFF1A0808);

// ── Status ────────────────────────────────────────────────────────────────────
const Color kOnlineGreen  = Color(0xFF2E7D32);
const Color kOnlineLight  = Color(0xFFE8F5E9);
const Color kAmberWarning = Color(0xFFE65100);

// ── Spacing (8-pt grid) ───────────────────────────────────────────────────────
const double kSpaceXXS  = 2;
const double kSpaceXS   = 4;
const double kSpaceSM   = 8;
const double kSpaceMD   = 12;
const double kSpaceLG   = 16;
const double kSpaceXL   = 22;
const double kSpaceXXL  = 32;
const double kSpaceXXXL = 48;

// ── Border radius ─────────────────────────────────────────────────────────────
const double kRadiusSM   = 8;
const double kRadiusMD   = 12;
const double kRadiusLG   = 14;  // buttons, inputs
const double kRadiusXL   = 16;  // cards
const double kRadiusXXL  = 20;  // large cards
const double kRadiusSheet = 26; // bottom sheet top
const double kRadiusPill  = 99; // pills

// ── Component sizes ───────────────────────────────────────────────────────────
const double kMinTapTarget           = 48;
const double kButtonHeight           = 54;
const double kEmergencyButtonSize    = 158; // circle diameter
const double kCardElevation          = 0;
const double kModalElevation         = 8;
const double kBottomNavHeight        = 64;

// ── Typography scale (px / weight per spec) ──────────────────────────────────
// Display  34 / 700–800
// Title    26 / 700
// Heading  22 / 700
// Subhead  18 / 600
// Body     16–17 / 400
// Small    13–14 / 400–500
// Caption  11 / 700 uppercase
const double kFontDisplay = 34;
const double kFontTitle   = 26;
const double kFontHeading = 22;
const double kFontSubhead = 18;
const double kFontBody    = 16;
const double kFontSmall   = 14;
const double kFontCaption = 11;

// Legacy aliases kept for backward compat
const double kFontXS  = kFontCaption;
const double kFontSM  = kFontSmall;
const double kFontMD  = kFontBody;
const double kFontLG  = kFontSubhead;
const double kFontXL  = kFontTitle;
const double kFontXXL = kFontDisplay;

// ── Shadows ───────────────────────────────────────────────────────────────────
List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.04),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> kRaisedCardShadow = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.06),
    blurRadius: 12,
    offset: const Offset(0, 2),
  ),
];

List<BoxShadow> kEmergencyButtonShadow = [
  BoxShadow(
    color: kRed600.withValues(alpha: 0.35),
    blurRadius: 24,
    offset: const Offset(0, 6),
  ),
];

List<BoxShadow> kTealButtonShadow = [
  BoxShadow(
    color: kTeal600.withValues(alpha: 0.30),
    blurRadius: 20,
    offset: const Offset(0, 5),
  ),
];

List<BoxShadow> kDriverButtonShadow = [
  BoxShadow(
    color: kBlue600.withValues(alpha: 0.30),
    blurRadius: 20,
    offset: const Offset(0, 5),
  ),
];
