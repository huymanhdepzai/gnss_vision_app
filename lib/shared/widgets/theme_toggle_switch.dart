import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/providers/theme_provider.dart';

class ThemeToggleSwitch extends StatefulWidget {
  final double width;
  final double height;

  const ThemeToggleSwitch({Key? key, this.width = 80, this.height = 40})
    : super(key: key);

  @override
  State<ThemeToggleSwitch> createState() => _ThemeToggleSwitchState();
}

class _ThemeToggleSwitchState extends State<ThemeToggleSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(bool isDark) async {
    HapticFeedback.mediumImpact();

    final themeProvider = context.read<ThemeProvider>();

    if (isDark) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    await themeProvider.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final iconColor = isDark
            ? AppTheme.secondaryColor
            : AppTheme.primaryColor;
        final glowColor = isDark
            ? AppTheme.secondaryColor.withOpacity(0.3)
            : AppTheme.primaryColor.withOpacity(0.2);

        return GestureDetector(
          onTap: () => _onTap(isDark),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.primaryColor.withOpacity(0.2),
                        AppTheme.secondaryColor.withOpacity(0.1),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: isDark ? 20 : 10,
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: isDark ? widget.width - widget.height + 5 : 5,
                  top: 5,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform(
                        transform: Matrix4.identity()
                          ..rotateY(_rotationAnimation.value)
                          ..scale(_scaleAnimation.value),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: Container(
                      width: widget.height - 10,
                      height: widget.height - 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [iconColor, iconColor.withOpacity(0.7)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_rounded,
                        color: Colors.white,
                        size: (widget.height - 10) * 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
