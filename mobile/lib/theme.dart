import 'package:flutter/material.dart';

// Cyan-blue primary + white surfaces, per project spec.
const Color kCyanBlue = Color(0xFF00BCD4);
const Color kCyanBlueDark = Color(0xFF0097A7);
const Color kCyanBlueLight = Color(0xFFB2EBF2);

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kCyanBlue,
    primary: kCyanBlue,
    onPrimary: Colors.white,
    secondary: kCyanBlueDark,
    surface: Colors.white,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: kCyanBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kCyanBlue,
      unselectedItemColor: Colors.black54,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kCyanBlue,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kCyanBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kCyanBlue, width: 2),
      ),
    ),
  );
}
