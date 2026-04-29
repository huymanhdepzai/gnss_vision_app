import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─── Primary Palette ────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF7C6AFF);
  static const Color primaryLight = Color(0xFF9B8AFF);
  static const Color primaryDark = Color(0xFF5F52E0);

  static const Color secondaryColor = Color(0xFF22D3EE);
  static const Color secondaryLight = Color(0xFF67E8F9);
  static const Color secondaryDark = Color(0xFF0891B2);

  static const Color accentColor = Color(0xFFF87171);
  static const Color successColor = Color(0xFF6EE7A0);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color infoColor = Color(0xFF60A5FA);

  // ─── Dark Surfaces ──────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0C1222);
  static const Color surfaceDark = Color(0xFF111A2E);
  static const Color cardDark = Color(0xFF1A2340);
  static const Color elevatedDark = Color(0xFF222D4A);

  // ─── Light Surfaces ──────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFEEF1F8);
  static const Color elevatedLight = Color(0xFFF8FAFF);

  // ─── Semantic Colors ────────────────────────────────────────────
  static const Color textDark = Color(0xFF1A1F36);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color surfaceVariantDark = Color(0xFF243050);
  static const Color surfaceVariantLight = Color(0xFFE4E9F2);
  static const Color outlineDark = Color(0xFF3A4768);
  static const Color outlineLight = Color(0xFFC8D0DE);

  static const Color onSurfaceDark = Color(0xFFE8ECF4);
  static const Color onSurfaceLight = Color(0xFF1A1F36);
  static const Color onSurfaceVariantDark = Color(0xFF8B97B0);
  static const Color onSurfaceVariantLight = Color(0xFF6B7794);

  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFEF4444);

  // ─── Gradients ───────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient primaryGradientWith({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: const [primaryColor, secondaryColor],
      begin: begin,
      end: end,
    );
  }

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryColor, Color(0xFF7DD3FC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFFCA5A5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF6EE7A0), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF131D33), Color(0xFF0C1222)],
  );

  static const LinearGradient surfaceGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FB)],
  );

  // ─── Decorations ─────────────────────────────────────────────────

  static BoxDecoration glassDecoration({Color? tintColor, bool isDark = true}) {
    final bg = tintColor ?? Colors.white;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bg.withOpacity(isDark ? 0.12 : 0.08),
          bg.withOpacity(isDark ? 0.04 : 0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(UIConsts.radiusXL),
      border: Border.all(
        color: bg.withOpacity(isDark ? 0.15 : 0.1),
        width: 1,
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  static BoxDecoration neumorphicDecoration({
    bool isPressed = false,
    bool isDark = true,
  }) {
    final bgColor = isDark ? cardDark : cardLight;
    final topShadow = isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.9);
    final bottomShadow = isDark ? const Color(0xFF050A18) : const Color(0xFFD0D5E0);

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(UIConsts.radiusXL),
      boxShadow: isPressed
          ? [
              BoxShadow(color: bottomShadow, offset: const Offset(3, 3), blurRadius: 6),
              BoxShadow(color: topShadow, offset: const Offset(-2, -2), blurRadius: 6),
            ]
          : [
              BoxShadow(color: topShadow, offset: const Offset(-4, -4), blurRadius: 10),
              BoxShadow(color: bottomShadow, offset: const Offset(4, 4), blurRadius: 10),
            ],
    );
  }

  static BoxDecoration glowDecoration(Color glowColor, {double radius = UIConsts.radiusXL}) {
    return BoxDecoration(
      color: surfaceDark,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(color: glowColor.withOpacity(0.25), blurRadius: 18, spreadRadius: -4),
        BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: 40, spreadRadius: -8),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? accentColor,
    double radius = UIConsts.radiusXL,
  }) {
    final bg = isDark ? cardDark : cardLight;
    final borderColor = accentColor != null
        ? accentColor.withOpacity(isDark ? 0.18 : 0.12)
        : (isDark ? Colors.white.withOpacity(0.06) : outlineLight.withOpacity(0.4));

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0xFF050A18).withOpacity(0.5) : Colors.black.withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        if (accentColor != null)
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  static BoxDecoration iconContainerDecoration({
    required bool isDark,
    required Color color,
    double radius = UIConsts.radiusLG,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withOpacity(isDark ? 0.2 : 0.12),
          color.withOpacity(isDark ? 0.05 : 0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(isDark ? 0.22 : 0.15), width: 1),
      boxShadow: [
        BoxShadow(color: color.withOpacity(isDark ? 0.15 : 0.08), blurRadius: 10, offset: const Offset(0, 3)),
      ],
    );
  }

  static BoxDecoration gradientButtonDecoration({required Gradient gradient, required bool isDark}) {
    final primary = gradient.colors.first;
    final secondary = gradient.colors.last;
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(UIConsts.radiusLG),
      boxShadow: [
        BoxShadow(color: primary.withOpacity(isDark ? 0.35 : 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        BoxShadow(color: secondary.withOpacity(isDark ? 0.12 : 0.08), blurRadius: 8, offset: const Offset(-2, -2)),
      ],
    );
  }

  static BoxDecoration outlineButtonDecoration({required Color color, required bool isDark}) {
    return BoxDecoration(
      border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3), width: 1.5),
      borderRadius: BorderRadius.circular(UIConsts.radiusLG),
      color: color.withOpacity(isDark ? 0.06 : 0.04),
      boxShadow: [
        BoxShadow(color: color.withOpacity(isDark ? 0.06 : 0.03), blurRadius: 10, offset: const Offset(0, 3)),
      ],
    );
  }

  // ─── Semantic Color Helpers ──────────────────────────────────────

  static Color adaptiveSurface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color adaptiveCard(bool isDark) => isDark ? cardDark : cardLight;
  static Color adaptiveElevated(bool isDark) => isDark ? elevatedDark : elevatedLight;
  static Color adaptiveBackground(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color adaptiveText(bool isDark) => isDark ? onSurfaceDark : onSurfaceLight;
  static Color adaptiveSubtext(bool isDark) => isDark ? onSurfaceVariantDark : onSurfaceVariantLight;
  static Color adaptiveOutline(bool isDark) => isDark ? outlineDark : outlineLight;
  static Color adaptiveBorder(bool isDark) => isDark ? Colors.white.withOpacity(0.06) : outlineLight.withOpacity(0.4);
  static Color adaptiveShadow(bool isDark) => isDark ? const Color(0xFF050A18) : Colors.black;
  static Color adaptiveDivier(bool isDark) => isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

  static Color withAdaptiveOpacity(Color color, double darkOpacity, double lightOpacity, {required bool isDark}) {
    return color.withOpacity(isDark ? darkOpacity : lightOpacity);
  }

  // ─── Themes ──────────────────────────────────────────────────────

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
        surface: surfaceDark,
        onSurface: onSurfaceDark,
        surfaceContainerHighest: surfaceVariantDark,
        outline: outlineDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: onSurfaceDark, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        iconTheme: IconThemeData(color: onSurfaceVariantDark),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusLG)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: onSurfaceVariantDark),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cardDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusLG)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusMD)),
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
        thickness: 1,
        indent: UIConsts.spacingLG,
        endIndent: UIConsts.spacingLG,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusXL)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantDark,
        selectedColor: primaryColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusFull)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: onSurfaceDark, letterSpacing: -0.5, height: 1.2),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurfaceDark, letterSpacing: -0.3, height: 1.25),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: onSurfaceDark, letterSpacing: -0.2, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceDark, letterSpacing: -0.1, height: 1.35),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurfaceDark, height: 1.4),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurfaceVariantDark, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, color: onSurfaceDark, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: onSurfaceVariantDark, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariantDark, height: 1.45),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurfaceDark, letterSpacing: 0.2, height: 1.4),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onSurfaceVariantDark, letterSpacing: 0.5, height: 1.35),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVariantDark, letterSpacing: 0.8, height: 1.3),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: accentColor,
        surface: surfaceLight,
        onSurface: onSurfaceLight,
        surfaceContainerHighest: surfaceVariantLight,
        outline: outlineLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withOpacity(0.92),
        elevation: 0,
        titleTextStyle: const TextStyle(color: onSurfaceLight, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: onSurfaceLight),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusLG)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: onSurfaceVariantLight),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusLG)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusMD)),
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.05),
        thickness: 1,
        indent: UIConsts.spacingLG,
        endIndent: UIConsts.spacingLG,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusXL)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantLight,
        selectedColor: primaryColor.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusFull)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: onSurfaceLight, letterSpacing: -0.5, height: 1.2),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurfaceLight, letterSpacing: -0.3, height: 1.25),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: onSurfaceLight, letterSpacing: -0.2, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceLight, letterSpacing: -0.1, height: 1.35),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurfaceLight, height: 1.4),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurfaceVariantLight, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, color: onSurfaceLight, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: onSurfaceVariantLight, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariantLight, height: 1.45),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurfaceLight, letterSpacing: 0.2, height: 1.4),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onSurfaceVariantLight, letterSpacing: 0.5, height: 1.35),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVariantLight, letterSpacing: 0.8, height: 1.3),
      ),
    );
  }
}

class UIConsts {
  UIConsts._();

  // ─── Spacing ─────────────────────────────────────────────────────
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 20.0;
  static const double spacing2XL = 24.0;
  static const double spacing3XL = 32.0;
  static const double spacing4XL = 48.0;

  // ─── Radius ──────────────────────────────────────────────────────
  static const double radiusXS = 8.0;
  static const double radiusSM = 10.0;
  static const double radiusMD = 14.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radius2XL = 24.0;
  static const double radius3XL = 28.0;
  static const double radiusFull = 999.0;

  // ─── Icon Sizes ───────────────────────────────────────────────────
  static const double iconSizeXS = 14.0;
  static const double iconSizeSM = 18.0;
  static const double iconSizeMD = 22.0;
  static const double iconSizeLG = 28.0;
  static const double iconSizeXL = 36.0;

  // ─── Button Heights ───────────────────────────────────────────────
  static const double buttonHeightSM = 40.0;
  static const double buttonHeightMD = 48.0;
  static const double buttonHeightLG = 56.0;

  // ─── Avatar Sizes ────────────────────────────────────────────────
  static const double avatarSizeSM = 28.0;
  static const double avatarSizeMD = 40.0;
  static const double avatarSizeLG = 56.0;
  static const double avatarSizeXL = 80.0;

  // ─── Animation Durations ─────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animEntrance = Duration(milliseconds: 600);
  static const Duration animSplash = Duration(milliseconds: 1500);

  // ─── Animation Curves ─────────────────────────────────────────────
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveEntrance = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSmooth = Curves.easeInOutCubic;

  // ─── Elevation ───────────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;
  static const double elevationXL = 16.0;

  // ─── Opacity ─────────────────────────────────────────────────────
  static const double opacityDisabled = 0.38;
  static const double opacityHint = 0.5;
  static const double opacitySubtle = 0.6;
  static const double opacityMedium = 0.75;
  static const double opacityFull = 1.0;
}