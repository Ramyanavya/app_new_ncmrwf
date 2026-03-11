// lib/utils/constants.dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary       = Color(0xFF2D7D9A);
  static const Color primaryDark   = Color(0xFF1A5C73);
  static const Color accent        = Color(0xFF4ECDC4);
  static const Color bgDark        = Color(0xFF1E3A4A);
  static const Color bgCard        = Color(0xFF2A4A5A);
  static const Color bgCardLight   = Color(0xFF3A5A6A);
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFFB0C4CC);
  static const Color textMuted     = Color(0xFF7A9AA8);
  static const Color warning       = Color(0xFFF6C90E);
  static const Color success       = Color(0xFF4ECDC4);
  static const Color bottomNav     = Color(0xFFFFF9C4);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.bgCard,
    ),
    cardColor: AppColors.bgCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color:      AppColors.textPrimary,
        fontSize:   18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary),
      bodyLarge:    TextStyle(color: AppColors.textPrimary),
      bodyMedium:   TextStyle(color: AppColors.textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     AppColors.bottomNav,
      selectedItemColor:   AppColors.primary,
      unselectedItemColor: Colors.grey,
      type:                BottomNavigationBarType.fixed,
      elevation:           8,
    ),
  );
}

class AppConstants {
  // NCMRWF surface weather API — no pressure levels, no FastAPI backend
  static const String ncmrwfBaseUrl = 'https://api.ncmrwf.gov.in/appapi/';
  static const String ncmrwfAppId   = '921155810533297639420383389872';

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi',   'native': 'हिन्दी'},
  ];
}