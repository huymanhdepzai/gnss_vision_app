import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';

class MapNavigationTopBar extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;

  const MapNavigationTopBar({
    Key? key,
    required this.state,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppTheme.backgroundDark.withOpacity(0.97),
                    AppTheme.backgroundDark.withOpacity(0.65),
                    Colors.transparent
                  ]
                : [
                    Colors.white.withOpacity(0.97),
                    Colors.white.withOpacity(0.65),
                    Colors.transparent
                  ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 10, 16, 28),
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
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: (isDark ? AppTheme.primaryColor : AppTheme.outlineLight)
                    .withOpacity(0.12),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: (isDark ? AppTheme.primaryColor : Colors.black)
                      .withOpacity(0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 6)),
              BoxShadow(
                  color: (isDark ? AppTheme.secondaryColor : Colors.black)
                      .withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(-2, -2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.successColor.withOpacity(0.22),
                        AppTheme.successColor.withOpacity(0.06)
                      ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.18), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.turn_right_rounded,
                    color: AppTheme.successColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Đang hướng tới",
                        style: TextStyle(
                            color: (isDark ? Colors.white : AppTheme.textDark)
                                .withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(state.destinationName,
                        style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}