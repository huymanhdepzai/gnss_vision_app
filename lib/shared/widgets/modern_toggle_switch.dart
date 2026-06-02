import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class ModernToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;

  const ModernToggleSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
    this.activeIcon = Icons.check,
    this.inactiveIcon = Icons.close,
    this.activeColor,
    this.inactiveColor,
    this.width = 65,
    this.height = 34,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeActiveColor = activeColor ?? AppTheme.primaryColor;
    final themeInactiveColor = inactiveColor ?? Colors.grey.withOpacity(0.3);
    
    final currentColor = value ? themeActiveColor : themeInactiveColor;
    final glowColor = value 
        ? themeActiveColor.withOpacity(0.3) 
        : Colors.transparent;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: value 
              ? themeActiveColor.withOpacity(0.1) 
              : Colors.grey.withOpacity(0.05),
          border: Border.all(
            color: value 
                ? themeActiveColor.withOpacity(0.3) 
                : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              left: value ? width - height + 4 : 4,
              top: 4,
              bottom: 4,
              child: Container(
                width: height - 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      currentColor,
                      currentColor.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  value ? activeIcon : inactiveIcon,
                  color: Colors.white,
                  size: (height - 8) * 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
