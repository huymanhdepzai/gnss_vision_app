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

  String _getArrivalTime(String durationText) {
    try {
      int minutes = 0;
      final RegExp hourRegExp = RegExp(r'(\d+)\s*giờ');
      final RegExp minRegExp = RegExp(r'(\d+)\s*phút');

      final hourMatch = hourRegExp.firstMatch(durationText);
      final minMatch = minRegExp.firstMatch(durationText);

      if (hourMatch != null) {
        minutes += int.parse(hourMatch.group(1)!) * 60;
      }
      if (minMatch != null) {
        minutes += int.parse(minMatch.group(1)!);
      }

      if (minutes == 0 && durationText.isNotEmpty) {
        final RegExp fallbackRegExp = RegExp(r'(\d+)');
        final fallbackMatch = fallbackRegExp.firstMatch(durationText);
        if (fallbackMatch != null) {
          minutes = int.parse(fallbackMatch.group(1)!);
        }
      }

      final arrivalTime = DateTime.now().add(Duration(minutes: minutes));
      return "${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "--:--";
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final arrivalTime = _getArrivalTime(state.duration);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onStartVision,
                            borderRadius: BorderRadius.circular(30),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "GNSS-Vision",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: isDark ? AppTheme.cardDark.withOpacity(0.85) : Colors.white.withOpacity(0.9),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.5) : AppTheme.primaryColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.duration,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.successColor,
                                    letterSpacing: -1,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      state.vehicle == 'bike'
                                          ? Icons.two_wheeler_rounded
                                          : state.vehicle == 'foot'
                                              ? Icons.directions_walk_rounded
                                              : Icons.directions_car_rounded,
                                      size: 18,
                                      color: textColor.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      state.distance,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.schedule_rounded, size: 18, color: textColor.withOpacity(0.6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      arrivalTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onExitNavigation,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.accentColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppTheme.accentColor,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
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