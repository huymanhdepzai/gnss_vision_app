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
  final ValueChanged<String> onVehicleSelected;
  final ValueChanged<int> onRouteSelected;
  final Animation<Offset> slideAnimation;
  final EdgeInsets padding;

  const MapPlaceSheet({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onStartNavigation,
    required this.onFetchAndDrawRoute,
    required this.onVehicleSelected,
    required this.onRouteSelected,
    required this.slideAnimation,
    required this.padding,
  }) : super(key: key);

  Color _a(Color c, double o) => c.withOpacity(o);

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, padding.bottom),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [_a(AppTheme.primaryColor, 0.08), _a(AppTheme.backgroundDark, 0.95)]
                        : [Colors.white, _a(AppTheme.surfaceLight, 0.9)],
                  ),
                  border: Border.all(
                    color: isDark ? _a(Colors.white, 0.08) : _a(AppTheme.primaryColor, 0.06),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? _a(Colors.white, 0.2) : _a(Colors.black, 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPlaceIcon(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.destinationName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.destinationAddress,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(),
                    const SizedBox(height: 16),
                    _buildVehicleSelection(),
                    if (state.availableRoutes.length > 1) ...[
                      const SizedBox(height: 16),
                      _buildRouteSelection(),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrimaryButton(
                            text: "Bắt đầu",
                            icon: Icons.navigation_rounded,
                            onTap: onStartNavigation,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildSecondaryButton(
                          icon: Icons.route_rounded,
                          onTap: onFetchAndDrawRoute,
                        ),
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

  Widget _buildPlaceIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_a(AppTheme.accentColor, 0.2), _a(AppTheme.accentColor, 0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _a(AppTheme.accentColor, 0.2), width: 1),
      ),
      child: const Icon(Icons.place_rounded, color: AppTheme.accentColor, size: 28),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        _infoChip(Icons.straighten_rounded, state.distance, AppTheme.primaryColor),
        const SizedBox(width: 12),
        _infoChip(Icons.access_time_rounded, state.duration, AppTheme.secondaryColor),
      ],
    );
  }

  Widget _infoChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _a(color, isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(color, 0.12), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: isDark ? _a(Colors.white, 0.8) : AppTheme.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _vehicleOption('car', Icons.directions_car_rounded, 'Ô tô'),
        const SizedBox(width: 12),
        _vehicleOption('bike', Icons.two_wheeler_rounded, 'Xe máy'),
        const SizedBox(width: 12),
        _vehicleOption('foot', Icons.directions_walk_rounded, 'Đi bộ'),
      ],
    );
  }

  Widget _vehicleOption(String vehicleType, IconData icon, String label) {
    final isSelected = state.vehicle == vehicleType;
    final color = isSelected
        ? AppTheme.primaryColor
        : (isDark ? Colors.white54 : Colors.black54);

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          onVehicleSelected(vehicleType);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _a(AppTheme.primaryColor, isDark ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tuyến đường thay thế",
          style: TextStyle(
            color: isDark ? Colors.white70 : AppTheme.textDark.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.availableRoutes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final route = state.availableRoutes[index];
              final isSelected = state.selectedRouteIndex == index;
              return GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.selectionClick();
                    onRouteSelected(index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _a(AppTheme.secondaryColor, isDark ? 0.15 : 0.08)
                        : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.secondaryColor
                          : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                      width: 1.5,
                    ),
                    ),
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        route.durationText,
                        style: TextStyle(
                          color: isSelected ? AppTheme.secondaryColor : (isDark ? Colors.white60 : Colors.black54),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        route.distanceText,
                        style: TextStyle(
                          color: isSelected ? AppTheme.secondaryColor.withOpacity(0.7) : (isDark ? Colors.white30 : Colors.black.withOpacity(0.3)),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: isDark ? _a(Colors.white, 0.05) : _a(AppTheme.primaryColor, 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? _a(Colors.white, 0.1) : _a(AppTheme.primaryColor, 0.1),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : AppTheme.primaryColor,
          size: 24,
        ),
      ),
    );
  }
}
