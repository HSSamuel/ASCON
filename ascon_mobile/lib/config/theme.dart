import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF1B5E3A);
  static const Color accentGold = Color(0xFFD4AF37);

  // 🌞 LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
    cardColor: Colors.white,
    dividerColor: Colors.grey[200],
    
    // ✅ NEW: Fix Invisible Cursor & Text Selection
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primaryGreen,
      selectionColor: primaryGreen.withOpacity(0.3),
      selectionHandleColor: primaryGreen,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: Colors.grey[500]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
    ),

    textTheme: GoogleFonts.latoTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87), 
        bodyMedium: TextStyle(color: Colors.black54), 
      ),
    ),
    
    iconTheme: const IconThemeData(color: primaryGreen),
    colorScheme: ColorScheme.fromSwatch().copyWith(secondary: accentGold),
  );

  // 🌙 DARK THEME
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: Colors.grey[800],

    // ✅ NEW: Fix Invisible Cursor in Dark Mode
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accentGold,
      selectionColor: accentGold.withOpacity(0.3),
      selectionHandleColor: accentGold,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF14452B), 
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      hintStyle: TextStyle(color: Colors.grey[500]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
    ),

    textTheme: GoogleFonts.latoTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: Colors.white), 
        bodyMedium: TextStyle(color: Colors.grey), 
      ),
    ),

    iconTheme: const IconThemeData(color: Color(0xFF81C784)),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(secondary: accentGold),
  );
}