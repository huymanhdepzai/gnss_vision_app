import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';

class MapFloatingButtons extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;
  final VoidCallback onMyLocation;
  final VoidCallback onToggleAssistant;
  final VoidCallback onToggleMapMode;
  final bool is3DMode;
  final Animation<double> fabScaleAnimation;
  final Animation<double> pulseAnimation;
  final bool hasNewMessage;

  const MapFloatingButtons({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onMyLocation,
    required this.onToggleAssistant,
    required this.onToggleMapMode,
    required this.is3DMode,
    required this.fabScaleAnimation,
    required this.pulseAnimation,
    this.hasNewMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fabScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: fabScaleAnimation.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Assistant Button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      // Calculate wiggle angle based on pulseAnimation
                      final t = (pulseAnimation.value - 1.0) / 0.15;
                      // Shake when there's a new message
                      final angle = hasNewMessage ? math.sin(t * math.pi * 3) * 0.12 : 0.0;
                      return Transform.rotate(
                        angle: angle,
                        child: FloatingActionButton(
                          heroTag: "btn_assistant",
                          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                          elevation: hasNewMessage ? 8 : 6,
                          shape: const CircleBorder(),
                          onPressed: onToggleAssistant,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/bot-svg.svg',
                              colorFilter: const ColorFilter.mode(
                                  AppTheme.primaryColor, BlendMode.srcIn),
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (hasNewMessage)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (context, child) {
                          // Extra pop for the badge scaling
                          final scale = 1.0 + ((pulseAnimation.value - 1.0) * 1.5);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? AppTheme.cardDark : Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF5252).withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Map Mode Toggle Button
              FloatingActionButton(
                heroTag: "btn_map_mode",
                backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                elevation: 6,
                shape: const CircleBorder(),
                onPressed: onToggleMapMode,
                child: Icon(
                  is3DMode ? Icons.view_in_ar_rounded : Icons.map_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.secondaryColor.withOpacity(
                                0.35 * (2 - pulseAnimation.value)),
                            blurRadius: 18,
                            spreadRadius: 1),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: "btn_location",
                      backgroundColor: isDark ? AppTheme.cardDark : Colors
                          .white,
                      elevation: 6,
                      shape: const CircleBorder(),
                      onPressed: onMyLocation,
                      child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor
                                      .withOpacity(isDark ? 0.3 : 0.1),
                                  AppTheme.secondaryColor
                                      .withOpacity(isDark ? 0.25 : 0.05),
                                ])),
                        child: const Icon(Icons.my_location_rounded,
                            color: AppTheme.secondaryColor),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}