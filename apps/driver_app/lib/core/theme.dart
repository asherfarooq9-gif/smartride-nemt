import 'package:flutter/material.dart';

// Driver app uses teal/green to distinguish from the patient app (blue)
const _seed = Color(0xFF00695C);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  scaffoldBackgroundColor: const Color(0xFFF0FAF7),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00695C),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _seed,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
  ),
);

/// Primary teal — use for branded UI elements
const Color driverPrimary = Color(0xFF00695C);

/// Dark teal — use for section headers, emphasized text
const Color driverPrimaryDark = Color(0xFF004D40);

/// Online status green
const Color statusOnline = Color(0xFF2E7D32);

/// Offline / neutral grey
const Color statusOffline = Color(0xFF757575);

/// Error / danger red
const Color statusError = Color(0xFFD32F2F);
