import 'package:flutter/material.dart';

// ── Patient portal — Blue ─────────────────────────────────────────────────────
// 600 is for text and filled buttons (5.6:1 with white). The brighter iOS blue
// below is for icons, the location dot and selected pills only: it is 4.0:1
// on white, so it must never carry text.
const Color kPatient800 = Color(0xFF004C99);
const Color kPatient600 = Color(0xFF0066CC); // primary
const Color kPatient100 = Color(0xFFE3EEFC);
const Color kPatient50 = Color(0xFFF0F6FE);
const Color kBlueIos = Color(0xFF007AFF); // graphics only

const Color kPatientPrimary = kPatient600;

// ── Driver portal — same blue as the patient portal ───────────────────────────
// The driver screens used a darker steel blue, which did not match the side
// menu. Both portals now share one blue; the names stay so driver code is
// unchanged.
const Color kBlue800 = kPatient800;
const Color kBlue600 = kPatient600; // driver primary
const Color kBlue100 = kPatient100;
const Color kBlueAccentDark = Color(0xFF4AADDB); // driver accent in dark mode

const Color kDriverPrimary = kBlue600;

// ── Emergency — Red (RESERVED — never use for anything else) ──────────────────
const Color kRed800 = Color(0xFF9B1E1E);
const Color kRed600 = Color(0xFFC62828);
const Color kRed50 = Color(0xFFFFEBEE);
const Color kEmergencyRed = kRed600;
const Color kEmergencyRedHighlight =
    Color(0xFFCE2C2C); // top-left of the SOS button, 5.1:1 with white
const Color kError = kRed600;

// ── Neutrals — Light ─────────────────────────────────────────────────────────
const Color kText900 = Color(0xFF1C1C1E);
const Color kText600 = Color(0xFF48484A);
const Color kText400 = Color(0xFF6E6E73); // 4.8:1 on the page
const Color kCanvas = Color(0xFFF8F9FB); // page background
const Color kBorder = Color(0xFFD1D1D6);
const Color kBorderLight = Color(0xFFE5E5EA);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSurface2 = Color(0xFFF2F3F5);
const Color kBackground = kCanvas;
const Color kOnPrimary = Color(0xFFFFFFFF);
const Color kOnSurface = kText900;
const Color kTextSecondary = kText600;
const Color kDivider = kBorder;

// ── Neutrals — Dark ──────────────────────────────────────────────────────────
const Color kDarkBg = Color(0xFF0A0A0C); // near-black page
const Color kDarkSurface = Color(0xFF1C1C1E); // cards
const Color kDarkSurface2 = Color(0xFF2C2C2E); // raised cards, fields
const Color kDarkBorder = Color(0xFF3A3A3C);
const Color kDarkAccent = Color(0xFF4DA3FF); // blue on dark surfaces
const Color kDarkRed = Color(0xFFFF6961);
const Color kDarkPatientContainer = Color(0xFF0F2C52); // tinted card on dark
const Color kDarkOnPatientContainer = Color(0xFFBBD7FF);
const Color kDarkBlueContainer = Color(0xFF14324A);
const Color kDarkOnBlueContainer = Color(0xFFBFE0F2);
const Color kDarkText1 = Color(0xFFF2F2F7);
const Color kDarkText2 = Color(0xFFAEAEB2);
const Color kDarkText3 = Color(0xFF8E8E93); // 5.2:1 on cards

// ── Auth ──────────────────────────────────────────────────────────────────────
const Color kAuthDarkBg = Color(0xFF0A1628);
const Color kAuthAccent = kPatient600;
// Light surfaces for sign up and login.
const Color kAuthLightBg = Color(0xFFF5F8FB);
const Color kAuthFieldBg = Color(0xFFFFFFFF);
const Color kAuthFieldBorder = Color(0xFFCBD5E1);
const Color kAuthText = Color(0xFF0A1628);
const Color kAuthMuted = Color(0xFF4B5B70);
const Color kWelcomeGradStart = Color(0xFF3B8BE0);
const Color kWelcomeGradMid = kPatient600;
const Color kWelcomeGradEnd = Color(0xFF00356B);
const Color kEmergencyDarkBg = Color(0xFF1A0808);

// ── Status ────────────────────────────────────────────────────────────────────
const Color kOnlineGreen = Color(0xFF2E7D32);
const Color kAmberWarning = Color(0xFFE65100);

// ── Spacing (8-pt grid) ───────────────────────────────────────────────────────
const double kSpaceXS = 4;
const double kSpaceSM = 8;
const double kSpaceMD = 12;
const double kSpaceLG = 16;
const double kSpaceXL = 22;
const double kSpaceXXL = 32;

// ── Border radius ─────────────────────────────────────────────────────────────
const double kRadiusSM = 8;
const double kRadiusMD = 12;
const double kRadiusLG = 12; // buttons, inputs
const double kRadiusXL = 20; // cards
const double kRadiusXXL = 20; // large cards
const double kRadiusSheet = 28; // bottom sheet top
const double kRadiusPill = 99; // pills

// ── Component sizes ───────────────────────────────────────────────────────────
const double kMinTapTarget = 48;
const double kButtonHeight = 54;
const double kEmergencyButtonSize = 140; // circle diameter

// ── Typography scale (px / weight per spec) ──────────────────────────────────
// Display  34 / 700–800
// Title    26 / 700
// Heading  22 / 700
// Subhead  18 / 600
// Body     16–17 / 400
// Small    13–14 / 400–500
// Caption  11 / 700 uppercase
const double kFontDisplay = 34;
const double kFontTitle = 26;
const double kFontHeading = 22;
const double kFontSubhead = 18;
const double kFontBody = 16;
const double kFontSmall = 14;
const double kFontCaption = 11;

// Legacy aliases kept for backward compat
const double kFontSM = kFontSmall;
const double kFontMD = kFontBody;
const double kFontLG = kFontSubhead;

// ── Shadows ───────────────────────────────────────────────────────────────────
// Shadows are tinted with a deep teal ink, never pure black, so they stay clean
// on light surfaces.
const Color kShadowInk = Color(0xFF0B1F3A);

List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: kShadowInk.withValues(alpha: 0.06),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> kRaisedCardShadow = [
  BoxShadow(
    color: kShadowInk.withValues(alpha: 0.10),
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

List<BoxShadow> kPatientButtonShadow = [
  BoxShadow(
    color: kPatient600.withValues(alpha: 0.30),
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

/// Shadow for the home bottom sheet, cast upward over the map.
List<BoxShadow> kSheetShadow = [
  BoxShadow(
    color: kShadowInk.withValues(alpha: 0.16),
    blurRadius: 24,
    offset: const Offset(0, -4),
  ),
];
