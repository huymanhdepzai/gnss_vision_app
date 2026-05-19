import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';

class MapNavigationPanel extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;
  final VoidCallback onExitNavigation;
  final VoidCallback onStartVision;

  const MapNavigationPanel({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onExitNavigation,
    required this.onStartVision,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: FloatingActionButton.extended(
                        heroTag: "vision_btn",
                        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                        elevation: 6,
                        onPressed: onStartVision,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor
                              ]),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 16),
                        ),
                        label: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.accentGradient.createShader(bounds),
                            child: const Text("GNSS-Vision",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5))),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.cardDark.withOpacity(0.98),
                        AppTheme.surfaceDark.withOpacity(0.97)
                      ]
                    : [
                        Colors.white.withOpacity(0.98),
                        AppTheme.cardLight.withOpacity(0.97)
                      ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                  color: (isDark ? AppTheme.primaryColor : AppTheme.outlineLight)
                      .withOpacity(0.12),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: (isDark ? AppTheme.primaryColor : Colors.black)
                        .withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, -8)),
                BoxShadow(
                    color: (isDark ? AppTheme.secondaryColor : Colors.black)
                        .withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
                BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4)),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24,
                      MediaQuery.of(context).padding.bottom + 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.successColor.withOpacity(0.2),
                                AppTheme.successColor.withOpacity(0.05)
                              ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.15),
                              width: 1),
                          boxShadow: [
                            BoxShadow(
                                color: AppTheme.successColor.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.timer_rounded,
                            color: AppTheme.successColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.duration,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.successColor,
                                    letterSpacing: -0.5,
                                    shadows: [
                                  Shadow(
                                      color: AppTheme.successColor,
                                      blurRadius: 16)
                                ])),
                            Text("Khoảng cách: ${state.distance}",
                                style: TextStyle(
                                    color: (isDark
                                            ? Colors.white
                                            : AppTheme.textDark)
                                        .withOpacity(0.45),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onExitNavigation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.accentColor.withOpacity(0.16),
                                  AppTheme.accentColor.withOpacity(0.04)
                                ]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.accentColor.withOpacity(0.25),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.accentColor.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: const Text("Thoát",
                              style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}