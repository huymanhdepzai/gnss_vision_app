import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../bloc/map_home_state.dart';
import '../bloc/map_home_bloc.dart';

import '../../data/datasources/goong_search_data_source.dart';
import '../../../../core/utils/injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/domain/entities/saved_address_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MapPlaceSheet extends StatefulWidget {
  final MapHomeState state;
  final bool isDark;
  final VoidCallback onStartNavigation;
  final VoidCallback onFetchAndDrawRoute;
  final ValueChanged<String> onVehicleSelected;
  final ValueChanged<int> onRouteSelected;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  const MapPlaceSheet({
    Key? key,
    required this.state,
    required this.isDark,
    required this.onStartNavigation,
    required this.onFetchAndDrawRoute,
    required this.onVehicleSelected,
    required this.onRouteSelected,
    this.scrollController,
    required this.padding,
  }) : super(key: key);

  @override
  State<MapPlaceSheet> createState() => _MapPlaceSheetState();
}

class _MapPlaceSheetState extends State<MapPlaceSheet> {
  bool _isDetailsExpanded = false;
  bool _isRouteMode = false;

  Color _a(Color c, double o) => c.withOpacity(o);

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppTheme.textDark;
    final detail = widget.state.placeDetail;

    final authState = context.watch<AuthBloc>().state;
    final user = authState.maybeMap(
      authenticated: (s) => s.user,
      orElse: () => null,
    );
    final homeAddress = user?.homeAddress;
    final workAddress = user?.workAddress;
    final isHome = homeAddress?.placeId == widget.state.destinationPlaceId;
    final isWork = workAddress?.placeId == widget.state.destinationPlaceId;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.4 : 0.08),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isDark
                    ? [_a(AppTheme.primaryColor, 0.08), _a(AppTheme.backgroundDark, 0.95)]
                    : [Colors.white, _a(AppTheme.surfaceLight, 0.9)],
              ),
              border: Border.all(
                color: widget.isDark ? _a(Colors.white, 0.08) : _a(AppTheme.primaryColor, 0.06),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 12, 20, widget.padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? _a(Colors.white, 0.2) : _a(Colors.black, 0.1),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_isRouteMode) ...[
                    // CHẾ ĐỘ CHI TIẾT ĐỊA ĐIỂM
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
                                widget.state.destinationName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isHome || isWork) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isHome ? Colors.blue : Colors.orange).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isHome ? Icons.home_rounded : Icons.work_rounded,
                                        size: 14,
                                        color: isHome ? Colors.blue : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isHome ? "Nhà riêng" : "Công ty",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isHome ? Colors.blue : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ] else ...[
                                const SizedBox(height: 4),
                              ],
                              if (detail?.rating != null)
                                Row(
                                  children: [
                                    Text(
                                      detail!.rating!.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ...List.generate(5, (index) {
                                      return Icon(
                                        index < detail.rating!.floor()
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 14,
                                        color: Colors.amber,
                                      );
                                    }),
                                  ],
                                ),
                              Text(
                                widget.state.destinationAddress,
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
                        if (widget.state.destinationPlaceId != null)
                          IconButton(
                            icon: Icon(Icons.bookmark_add_outlined, color: textColor),
                            onPressed: () => _showSaveOptions(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (detail != null) 
                      _buildDetailedInfoSection(detail)
                    else if (widget.state.isSearching)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Đang tải thông tin chi tiết...",
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrimaryButton(
                            text: "Đường đi",
                            icon: Icons.route_rounded,
                            onTap: () {
                              setState(() => _isRouteMode = true);
                              widget.onFetchAndDrawRoute();
                            },
                            gradient: AppTheme.accentGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrimaryButton(
                            text: "Bắt đầu",
                            icon: Icons.navigation_rounded,
                            onTap: widget.onStartNavigation,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // CHẾ ĐỘ THÔNG TIN ĐƯỜNG ĐI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Chi tiết tuyến đường",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: widget.isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isRouteMode = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, 
                                size: 20, 
                                color: widget.isDark ? Colors.white70 : AppTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildVehicleSelection(widget.state),
                    const SizedBox(height: 16),
                    _buildInfoRow(widget.state),
                    if (widget.state.availableRoutes.length > 1) ...[
                      const SizedBox(height: 20),
                      _buildRouteSelection(widget.state),
                    ],
                    const SizedBox(height: 28),
                    _buildPrimaryButton(
                      text: "Bắt đầu",
                      icon: Icons.navigation_rounded,
                      onTap: widget.onStartNavigation,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedInfoSection(PlaceDetail detail) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDetailsExpanded = !_isDetailsExpanded;
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          "Thông tin địa điểm",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark ? Colors.white70 : AppTheme.textDark.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _isDetailsExpanded ? "Thu gọn" : "Xem thêm",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          _isDetailsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isDetailsExpanded) ...[
              const SizedBox(height: 16),
              if (detail.types != null && detail.types!.isNotEmpty) ...[
                _buildCategoryBadge(detail.types!.first),
                const SizedBox(height: 12),
              ],
              _buildDetailItem(
                Icons.access_time_filled_rounded,
                detail.isOpenNow == null 
                    ? "Không rõ trạng thái mở cửa" 
                    : (detail.isOpenNow! ? "Đang mở cửa" : "Hiện tại đóng cửa"),
                detail.isOpenNow == true ? Colors.green : (detail.isOpenNow == false ? Colors.red : Colors.grey),
                isAvailable: detail.isOpenNow != null,
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.phone_rounded, 
                detail.phoneNumber ?? "Chưa cập nhật số điện thoại", 
                Colors.blue,
                isAvailable: detail.phoneNumber != null,
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.language_rounded, 
                detail.website ?? "Chưa có thông tin website", 
                Colors.green,
                isAvailable: detail.website != null,
              ),
              if (detail.openingHours != null && detail.openingHours!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildOpeningHoursSummary(detail.openingHours!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String type) {
    // Chuyển đổi type từ snake_case sang Tiếng Việt nếu cần, hoặc đơn giản là capitalize
    final label = type.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, Color color, {bool isAvailable = true}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isAvailable ? FontWeight.w600 : FontWeight.w400,
              color: isAvailable 
                  ? (widget.isDark ? Colors.white.withOpacity(0.9) : AppTheme.textDark)
                  : (widget.isDark ? Colors.white38 : Colors.black38),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOpeningHoursSummary(List<String> hours) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 34),
      child: Text(
        "Xem chi tiết giờ mở cửa",
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.secondaryColor.withOpacity(0.8),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
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
        // Fallback for cases like "1 min" or just numbers
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

  Widget _buildInfoRow(MapHomeState state) {
    final arrivalTime = _getArrivalTime(state.duration);
    final textColor = widget.isDark ? Colors.white : AppTheme.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Đến nơi lúc $arrivalTime",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Khoảng cách: ${state.distance}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Text(
                state.duration,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection(MapHomeState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _vehicleOption('car', Icons.directions_car_rounded, state)),
          Expanded(child: _vehicleOption('bike', Icons.two_wheeler_rounded, state)),
          Expanded(child: _vehicleOption('foot', Icons.directions_walk_rounded, state)),
        ],
      ),
    );
  }

  Widget _vehicleOption(
      String vehicleType, IconData icon, MapHomeState state) {
    final isSelected = state.vehicle == vehicleType;
    final activeColor = AppTheme.primaryColor;
    final inactiveColor = widget.isDark ? Colors.white38 : Colors.black26;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          widget.onVehicleSelected(vehicleType);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? activeColor : inactiveColor,
        ),
      ),
    );
  }

  Widget _buildRouteSelection(MapHomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tuyến đường thay thế",
          style: TextStyle(
            color: widget.isDark ? Colors.white70 : AppTheme.textDark.withOpacity(0.7),
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
                    widget.onRouteSelected(index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _a(AppTheme.secondaryColor, widget.isDark ? 0.15 : 0.08)
                        : (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.secondaryColor
                          : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                      width: 1.5,
                    ),
                    ),
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        route.durationText,
                        style: TextStyle(
                          color: isSelected ? AppTheme.secondaryColor : (widget.isDark ? Colors.white60 : Colors.black54),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        route.distanceText,
                        style: TextStyle(
                          color: isSelected ? AppTheme.secondaryColor.withOpacity(0.7) : (widget.isDark ? Colors.white30 : Colors.black.withOpacity(0.3)),
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
    Gradient? gradient,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient ?? AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.first ?? AppTheme.primaryColor).withOpacity(0.3),
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
          color: widget.isDark ? _a(Colors.white, 0.05) : _a(AppTheme.primaryColor, 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark ? _a(Colors.white, 0.1) : _a(AppTheme.primaryColor, 0.1),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: widget.isDark ? Colors.white70 : AppTheme.primaryColor,
          size: 24,
        ),
      ),
    );
  }

  void _showSaveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Lưu địa chỉ",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.blue),
                ),
                title: Text("Nhà riêng", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _saveAddress(isHome: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.work_rounded, color: Colors.orange),
                ),
                title: Text("Công ty", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _saveAddress(isHome: false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAddress({required bool isHome}) async {
    final placeId = widget.state.destinationPlaceId;
    if (placeId == null) return;
    
    final address = SavedAddressEntity(
      placeId: placeId,
      description: widget.state.destinationName,
      lat: widget.state.destinationLat ?? 0,
      lng: widget.state.destinationLng ?? 0,
    );
    try {
      if (isHome) {
        await sl<AuthRepository>().updateHomeAddress(address);
      } else {
        await sl<AuthRepository>().updateWorkAddress(address);
      }
      if (mounted) {
        context.read<AuthBloc>().add(const AuthEvent.authCheckRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHome ? "Đã lưu địa chỉ nhà riêng" : "Đã lưu địa chỉ công ty",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 160,
              left: 16,
              right: 16,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Lỗi khi lưu địa chỉ",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 160,
              left: 16,
              right: 16,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
