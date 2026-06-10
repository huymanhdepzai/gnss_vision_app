import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';

class MapFloatingButtons extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;
  final VoidCallback onMyLocation;
  final VoidCallback onToggleAssistant;
  final Animation<double> fabScaleAnimation;
  final Animation<double> pulseAnimation;

  const MapFloatingButtons({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onMyLocation,
    required this.onToggleAssistant,
    required this.fabScaleAnimation,
    required this.pulseAnimation,
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
              FloatingActionButton.small(
                heroTag: "btn_assistant",
                backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                onPressed: onToggleAssistant,
                child: const Icon(Icons.smart_toy_rounded,
                    color: AppTheme.primaryColor),
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
                      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
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