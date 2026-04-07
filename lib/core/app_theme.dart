import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF00D4FF);
  static const Color accentColor = Color(0xFFFF5252);
  static const Color successColor = Color(0xFF69F0AE);
  static const Color warningColor = Color(0xFFFFAB40);

  static const Color backgroundDark = Color(0xFF0A0E21);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1A1F36);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryColor, Color(0xFF00F5FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF8A80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({Color? tintColor}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (tintColor ?? Colors.white).withOpacity(0.15),
          (tintColor ?? Colors.white).withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (tintColor ?? Colors.white).withOpacity(0.2),
        width: 1,
      ),
    );
  }

  static BoxDecoration neumorphicDecoration({bool isPressed = false}) {
    return BoxDecoration(
      color: cardDark,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(4, 4),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                offset: const Offset(-2, -2),
                blurRadius: 8,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(-4, -4),
                blurRadius: 10,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                offset: const Offset(4, 4),
                blurRadius: 10,
              ),
            ],
    );
  }

  static BoxDecoration glowDecoration(Color glowColor, {double radius = 20}) {
    return BoxDecoration(
      color: surfaceDark,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: glowColor.withOpacity(0.3),
          blurRadius: 15,
          spreadRadius: -5,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        error: accentColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white60),
      ),
    );
  }
}
