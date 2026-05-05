import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';

class MapPlaceSheet extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;
  final VoidCallback onStartNavigation;
  final VoidCallback onFetchAndDrawRoute;
  final Animation<Offset> slideAnimation;
  final EdgeInsets padding;

  const MapPlaceSheet({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onStartNavigation,
    required this.onFetchAndDrawRoute,
    required this.slideAnimation,
    required this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppTheme.cardDark.withOpacity(0.98),
                      AppTheme.surfaceDark.withOpacity(0.96)
                    ]
                  : [
                      Colors.white.withOpacity(0.98),
                      AppTheme.cardLight.withOpacity(0.96)
                    ],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: (isDark ? AppTheme.primaryColor : AppTheme.outlineLight)
                    .withOpacity(0.15),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: (isDark ? AppTheme.primaryColor : Colors.black)
                      .withOpacity(isDark ? 0.12 : 0.05),
                  blurRadius: 50,
                  offset: const Offset(0, -15)),
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, -8)),
            ],
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8)
                                ]))),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.accentColor.withOpacity(0.22),
                                  AppTheme.accentColor.withOpacity(0.06)
                                ]),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color:
                                    AppTheme.accentColor.withOpacity(0.25),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppTheme.accentColor.withOpacity(0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)),
                              BoxShadow(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(-2, -2)),
                            ],
                          ),
                          child: const Icon(Icons.place_rounded,
                              color: AppTheme.accentColor, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.destinationName,
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                      letterSpacing: -0.3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(state.destinationAddress,
                                  style: TextStyle(
                                      color: (isDark
                                              ? Colors.white
                                              : AppTheme.textDark)
                                          .withOpacity(0.4),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: _buildGradientButton(
                                text: "Bắt đầu",
                                icon: Icons.navigation_rounded,
                                gradient: const LinearGradient(colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor
                                ]),
                                onTap: onStartNavigation)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildOutlineButton(
                                text: "Xem đường",
                                icon: Icons.route_rounded,
                                onTap: onFetchAndDrawRoute)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(-2, -2)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border.all(
              color: AppTheme.secondaryColor.withOpacity(0.45), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.secondaryColor.withOpacity(0.06),
          boxShadow: [
            BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.secondaryColor, size: 20),
                  const SizedBox(width: 10),
                  Text(text,
                      style: TextStyle(
                          color: AppTheme.secondaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                ]),
          ),
        ),
      ),
    );
  }
}