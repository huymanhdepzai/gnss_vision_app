import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/satellite_data.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../pages/satellite_detail_page.dart';
import '../pages/satellite_export_list_page.dart';

class SatelliteDrawer extends StatelessWidget {
  final List<SatelliteData> satellites;
  final List<SatelliteData> filteredSatellites;
  final String filterSystem;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onExportRawData;

  const SatelliteDrawer({
    super.key,
    required this.satellites,
    required this.filteredSatellites,
    required this.filterSystem,
    required this.onFilterChanged,
    required this.onExportRawData,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: context.screenWidth * 0.82,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Ultra-modern Blur Background
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: context.backgroundColor.withOpacity(0.85),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(32)),
                  border: Border.all(
                    color: context.adaptiveOpacity(Colors.white, 0.1, 0.05),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildQuickStats(context),
                SizedBox(height: UIConsts.spacingLG),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildActionRow(context),
                        SizedBox(height: UIConsts.spacingXL),
                        _buildFilterSection(context),
                        SizedBox(height: UIConsts.spacingXL),
                        _buildSatelliteList(context),
                        SizedBox(height: UIConsts.spacing3XL),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hệ Thống",
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  "ĐỊNH VỊ VỆ TINH",
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          PressScale(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close_rounded, color: context.iconSecondaryColor, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final activeFixes = satellites.where((s) => s.usedInFix).length;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildMiniStat(context, "${satellites.length}", "Trong tầm"),
          SizedBox(width: 16),
          _buildMiniStat(context, "$activeFixes", "Cố định", color: AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String value, String label, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? context.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.textSecondaryColor.withOpacity(0.5),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildCircleAction(
            context,
            Icons.file_download_outlined,
            "Xuất",
            AppTheme.primaryColor,
            onExportRawData,
          ),
          SizedBox(width: 20),
          _buildCircleAction(
            context,
            Icons.history_rounded,
            "Lịch sử",
            AppTheme.secondaryColor,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SatelliteExportListPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        PressScale(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: kFilterSystems.map((sys) {
              final isActive = filterSystem == sys;
              final color = sys == 'ALL'
                  ? AppTheme.primaryColor
                  : (kSatelliteSystemColors[sys] ?? Colors.white);
              final label = kSatelliteSystemLabels[sys] ?? sys;

              return Padding(
                padding: EdgeInsets.only(left: 4),
                child: ModernChip(
                  label: label,
                  color: color,
                  isSelected: isActive,
                  onTap: () => onFilterChanged(sys),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSatelliteList(BuildContext context) {
    if (filteredSatellites.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: Opacity(
            opacity: 0.5,
            child: Column(
              children: [
                Icon(Icons.satellite_outlined, size: 48),
                SizedBox(height: 8),
                Text("Không có dữ liệu", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "DANH SÁCH CHI TIẾT (${filteredSatellites.length})",
            style: TextStyle(
              color: context.textSecondaryColor.withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredSatellites.length,
          itemBuilder: (context, index) {
            final sat = filteredSatellites[index];
            return SatelliteListItem(
              sat: sat,
              index: index,
            );
          },
        ),
      ],
    );
  }
}

class SatelliteListItem extends StatelessWidget {
  final SatelliteData sat;
  final int index;

  const SatelliteListItem({
    super.key,
    required this.sat,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = sat.usedInFix
        ? (kSatelliteSystemColors[sat.system] ?? Colors.white)
        : context.textSecondaryColor.withOpacity(0.5);

    return EntranceAnimation(
      delay: Duration(milliseconds: index * 15),
      duration: const Duration(milliseconds: 300),
      type: EntranceType.fadeSlideLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SatelliteDetailScreen(satellite: sat, themeColor: color),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: UIConsts.animNormal,
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                // PRN and Indicator
                SizedBox(
                  width: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (sat.usedInFix)
                        PulseWidget(
                          duration: const Duration(seconds: 2),
                          minScale: 0.8,
                          maxScale: 1.2,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Text(
                        "${sat.prn}",
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sat.system,
                        style: TextStyle(
                          color: context.textColor.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "E: ${sat.elevation.toStringAsFixed(0)}°  A: ${sat.azimuth.toStringAsFixed(0)}°",
                        style: TextStyle(
                          color: context.textSecondaryColor.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Signal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${sat.snr.toInt()}",
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    _buildTinySignalBars(sat.snr, color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTinySignalBars(double snr, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        double fill = ((snr / 45) * 3 - i).clamp(0.0, 1.0);
        return Container(
          width: 2.5,
          height: 4 + (i * 2),
          margin: const EdgeInsets.only(left: 1.5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1 + (fill * 0.9)),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
