import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/goong_search_data_source.dart';
import '../bloc/map_home_state.dart';

class MapSearchBar extends StatelessWidget {
  final MapHomeState state;
  final bool isDark;
  final UserEntity? user;
  final ValueChanged<String> onSearchChanged;
  final void Function(String placeId, String description) onSelectPlace;
  final VoidCallback onMenuTap;
  final VoidCallback onBackTap;
  final VoidCallback onClearSearch;
  final VoidCallback onProfileTap;
  final Animation<double> pulseAnimation;
  final EdgeInsets padding;

  const MapSearchBar({
    Key? key,
    required this.state,
    required this.isDark,
    this.user,
    required this.onSearchChanged,
    required this.onSelectPlace,
    required this.onMenuTap,
    required this.onBackTap,
    required this.onClearSearch,
    required this.onProfileTap,
    required this.pulseAnimation,
    required this.padding,
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
                    AppTheme.backgroundDark.withOpacity(0.95),
                    AppTheme.backgroundDark.withOpacity(0.7),
                    Colors.transparent
                  ]
                : [
                    Colors.white.withOpacity(0.98),
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.4),
                    Colors.transparent
                  ],
          ),
        ),
        padding: padding,
        child: Column(
          children: [
            _buildSearchInput(context),
            if (state.searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSearchResults(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppTheme.primaryColor.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryColor.withOpacity(0.06)
                : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          if (isDark)
            BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2)),
          if (!isDark)
            BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 8,
                offset: const Offset(0, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                if (state.viewState == MapViewState.explore)
                  _buildSearchIconButton(
                    onTap: onMenuTap,
                    icon: Icons.menu_rounded,
                    isDark: isDark,
                  ),
                if (state.viewState == MapViewState.explore)
                  const SizedBox(width: 8),
                if (state.viewState == MapViewState.placeDetail)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.destinationName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state.viewState == MapViewState.explore)
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                              text: state.searchQuery)
                          ..selection = TextSelection.fromPosition(
                              TextPosition(
                                  offset: state.searchQuery.length)),
                      onChanged: onSearchChanged,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        fillColor: Colors.transparent,
                        hintText: "Tìm kiếm điểm đến...",
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.35)
                              : Colors.black.withOpacity(0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                if (state.isSearching)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isDark
                              ? AppTheme.secondaryColor
                              : AppTheme.primaryColor),
                    ),
                  )
                else if (state.searchQuery.isNotEmpty)
                  _buildSearchIconButton(
                    onTap: onClearSearch,
                    icon: Icons.close_rounded,
                    isDark: isDark,
                    size: 16,
                  )
                else
                  _buildProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIconButton({
    required VoidCallback onTap,
    required IconData icon,
    required bool isDark,
    double size = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : AppTheme.primaryColor,
          size: size,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: onProfileTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryColor
                        .withOpacity(0.3 * pulseAnimation.value),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 3)),
                BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(-1, 1)),
              ],
            ),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Colors.transparent,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? const Icon(Icons.person_rounded,
                      color: Colors.white, size: 19)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor =
        isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.5);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.cardDark.withOpacity(0.9)
              : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppTheme.primaryColor.withOpacity(0.1),
              width: 1),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.5)
                    : AppTheme.primaryColor.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.searchResults.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 56,
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final place = state.searchResults[index];
                int delay = (index * 40).clamp(0, 250);
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 250 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                        offset: Offset(15 * (1 - value), 0),
                        child: Opacity(opacity: value, child: child));
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelectPlace(
                          place.placeId, place.description),
                      splashColor: AppTheme.primaryColor.withOpacity(0.08),
                      highlightColor:
                          AppTheme.primaryColor.withOpacity(0.04),
                      child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                      child: Row(
                      children: [
                        SizedBox(
                          width: 55,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            AppTheme.primaryColor
                                                .withOpacity(0.15),
                                            AppTheme.secondaryColor
                                                .withOpacity(0.1)
                                          ]
                                        : [
                                            AppTheme.primaryColor
                                                .withOpacity(0.12),
                                            AppTheme.secondaryColor
                                                .withOpacity(0.06)
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: isDark
                                          ? AppTheme.primaryColor
                                              .withOpacity(0.12)
                                          : AppTheme.primaryColor
                                              .withOpacity(0.1),
                                      width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(
                                                isDark ? 0.1 : 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ],
                                ),
                                child: ShaderMask(
                                  shaderCallback: (bounds) => AppTheme
                                      .primaryGradient
                                      .createShader(bounds),
                                  child: Icon(Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: isDark ? 18 : 20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place.distance != null
                                    ? _formatDistance(place.distance!)
                                    : "dist",
                                maxLines: 1,
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.secondaryColor
                                      : AppTheme.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      place.mainText ??
                                          place.description,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize:
                                              isDark ? 15 : 14,
                                          color: textColor,
                                          height: 1.3)),
                                  if ((place.secondaryText ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(place.secondaryText!,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: subtextColor,
                                            fontSize: 12,
                                            height: 1.3)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
  }