import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToastrTheme {
  // Original Toastr NeoPop Dark/Brutalist Palette
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF161616);
  static const Color cardSurface = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF2E2E2E);

  // Brand & NeoPop Accent Colors
  static const Color primaryYellow = Color(0xFFFFD60A);
  static const Color accentOrange = Color(0xFFFF5722);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color errorRed = Color(0xFFFF3B30);

  // Platform Specific Brand Colors
  static const Color swiggyOrange = Color(0xFFFC8019);
  static const Color zomatoRed = Color(0xFFE23744);
  static const Color blinkitYellow = Color(0xFFF8CB46);
  static const Color zeptoPurple = Color(0xFF8000FF);
  static const Color instamartPink = Color(0xFFFF5200);
  static const Color bigbasketGreen = Color(0xFF84C225);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryYellow,
      colorScheme: const ColorScheme.dark(
        primary: primaryYellow,
        secondary: accentOrange,
        surface: surface,
        error: errorRed,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
