import 'package:flutter/material.dart';
import '../app_theme.dart';

extension BuildContextExtensions on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => AppTheme.primaryColor;
  Color get secondaryColor => AppTheme.secondaryColor;
  Color get accentColor => AppTheme.accentColor;
  Color get successColor => AppTheme.successColor;
  Color get warningColor => AppTheme.warningColor;
  Color get errorColor => isDark ? AppTheme.errorDark : AppTheme.errorLight;

  Color get backgroundColor => isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
  Color get surfaceColor => isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
  Color get cardColor => isDark ? AppTheme.cardDark : AppTheme.cardLight;
  Color get surfaceVariantColor => isDark ? AppTheme.surfaceVariantDark : AppTheme.surfaceVariantLight;
  Color get outlineColor => isDark ? AppTheme.outlineDark : AppTheme.outlineLight;

  Color get textColor => isDark ? AppTheme.onSurfaceDark : AppTheme.onSurfaceLight;
  Color get textSecondaryColor => isDark ? AppTheme.onSurfaceVariantDark : AppTheme.onSurfaceVariantLight;
  Color get textHintColor => isDark ? Colors.white38 : Colors.black38;
  Color get textDisabledColor => isDark ? Colors.white24 : Colors.black26;

  Color get iconColor => isDark ? Colors.white70 : AppTheme.textDark;
  Color get iconSecondaryColor => isDark ? Colors.white38 : Colors.black45;

  Color get dividerColor => isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);
  Color get shadowColor => isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);
  Color get subtleShadowColor => isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.03);

  Color adaptiveColor(Color darkColor, Color lightColor) => isDark ? darkColor : lightColor;
  Color adaptiveOpacity(Color color, double darkOpacity, double lightOpacity) =>
      color.withOpacity(isDark ? darkOpacity : lightOpacity);

  ThemeData get theme => Theme.of(this);
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  double responsiveValue(double mobile, [double? tablet, double? desktop]) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  double get horizontalPadding => responsiveValue(16.0, 24.0, 32.0);
  double get cardPadding => responsiveValue(16.0, 20.0, 24.0);
  double get listPadding => responsiveValue(16.0, 24.0, 32.0);

  void showModernSnackBar({
    required String message,
    IconData? icon,
    Color? color,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBarColor = color ?? AppTheme.primaryColor;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: onPrimary, size: UIConsts.iconSizeSM),
              SizedBox(width: UIConsts.spacingMD),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: snackBarColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConsts.radiusMD)),
        margin: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          padding.bottom + UIConsts.spacingLG,
        ),
      ),
    );
  }

  Future<T?> showModernDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      builder: (_) => child,
    );
  }

  Future<T?> showModernBottomSheet<T>({
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightRatio,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
      constraints: maxHeightRatio != null
          ? BoxConstraints(maxHeight: screenHeight * maxHeightRatio)
          : null,
    );
  }

  Color get onPrimary => AppTheme.onPrimary;
}