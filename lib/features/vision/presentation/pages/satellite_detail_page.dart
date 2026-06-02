import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/entities/satellite_data.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';
import 'satellite_page.dart';

class SatelliteDetailScreen extends StatefulWidget {
  final SatelliteData satellite;
  final Color themeColor;

  const SatelliteDetailScreen({
    super.key,
    required this.satellite,
    required this.themeColor,
  });

  @override
  State<SatelliteDetailScreen> createState() => _SatelliteDetailScreenState();
}

class _SatelliteDetailScreenState extends State<SatelliteDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UIConsts.animEntrance,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: BreathingGlow(
              glowColor: widget.themeColor,
              minOpacity: 0.1,
              maxOpacity: 0.25,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.themeColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(UIConsts.spacingXL),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            _buildHeroHeader(context),
                            SizedBox(height: UIConsts.spacing3XL),
                            _buildMainStatsGrid(context),
                            SizedBox(height: UIConsts.spacingXL),
                            _buildSignalSection(context),
                            SizedBox(height: UIConsts.spacingXL),
                            _buildTechnicalDetails(context),
                          ],
                        ),
                      ),
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: UIConsts.spacingSM, vertical: UIConsts.spacingSM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(UIConsts.spacingSM),
              decoration: AppTheme.iconContainerDecoration(
                isDark: context.isDark,
                color: widget.themeColor,
                radius: UIConsts.radiusMD,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: widget.themeColor,
                size: UIConsts.iconSizeSM,
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [widget.themeColor, widget.themeColor.withOpacity(0.6)],
            ).createShader(bounds),
            child: const Text(
              "CHI TIẾT VỆ TINH",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          SizedBox(width: UIConsts.avatarSizeMD),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Column(
      children: [
        Hero(
          tag: 'sat_icon_${widget.satellite.prn}',
          child: SizedBox(
            width: 120,
            height: 120,
            // decoration: BoxDecoration(
            //   shape: BoxShape.circle,
            //   gradient: LinearGradient(
            //     colors: [widget.themeColor, widget.themeColor.withOpacity(0.5)],
            //     begin: Alignment.topLeft,
            //     end: Alignment.bottomRight,
            //   ),
            //   boxShadow: [
            //     BoxShadow(
            //       color: widget.themeColor.withOpacity(0.4),
            //       blurRadius: 30,
            //       spreadRadius: 5,
            //     ),
            //   ],
            // ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/satellite-icon.svg',
                width: 180,
                height: 180,
                // colorFilter:
                //     const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        SizedBox(height: UIConsts.spacingXL),
        Hero(
          tag: 'sat_prn_${widget.satellite.prn}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              "Vệ tinh #${widget.satellite.prn}",
              style: TextStyle(
                color: context.textColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingLG, vertical: UIConsts.spacingSM - 2),
          margin: EdgeInsets.only(top: UIConsts.spacingSM),
          decoration: BoxDecoration(
            color: widget.themeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(UIConsts.radiusFull),
            border: Border.all(color: widget.themeColor.withOpacity(0.3)),
          ),
          child: Text(
            widget.satellite.system,
            style: TextStyle(
              color: widget.themeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatsGrid(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(
          context,
          "SNR",
          "${widget.satellite.snr.toStringAsFixed(1)}",
          "dB-Hz",
          Icons.signal_cellular_alt_rounded,
        ),
        SizedBox(width: UIConsts.spacingMD),
        _buildStatCard(
          context,
          "CỐ ĐỊNH",
          widget.satellite.usedInFix ? "ĐANG DÙNG" : "KHÔNG",
          "",
          widget.satellite.usedInFix
              ? Icons.gps_fixed_rounded
              : Icons.gps_not_fixed_rounded,
          isHighlight: widget.satellite.usedInFix,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon, {
    bool isHighlight = false,
  }) {
    final accentColor = isHighlight ? widget.themeColor : null;

    return Expanded(
      child: ModernCard(
        accentColor: accentColor,
        hasGlow: isHighlight,
        padding: EdgeInsets.all(UIConsts.spacingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernIconContainer(
              icon: icon,
              color: isHighlight ? widget.themeColor : context.iconSecondaryColor,
              size: 42,
              iconSize: 20,
            ),
            SizedBox(height: UIConsts.spacingLG),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  SizedBox(width: UIConsts.spacingXS),
                  Padding(
                    padding: EdgeInsets.only(bottom: UIConsts.spacingXS),
                    child: Text(
                      unit,
                      style: TextStyle(
                          color: context.textSecondaryColor, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: UIConsts.spacingXS),
            Text(
              label,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalSection(BuildContext context) {
    return ModernCard(
      accentColor: widget.themeColor,
      padding: EdgeInsets.all(UIConsts.spacing2XL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: "CƯỜNG ĐỘ TÍN HIỆU",
            icon: Icons.signal_cellular_alt_rounded,
            color: widget.themeColor,
          ),
          SizedBox(height: UIConsts.spacing2XL),
          ModernProgressBar(
            progress: (widget.satellite.snr / 50).clamp(0.0, 1.0),
            color: widget.themeColor,
            height: 12,
          ),
          SizedBox(height: UIConsts.spacingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.satellite.snr > 30 ? "Tín hiệu mạnh và ổn định" : "Tín hiệu trung bình",
                style: TextStyle(
                    color: context.textSecondaryColor, fontSize: 12),
              ),
              ModernBadge(
                text: "${widget.satellite.snr.toInt()} dB-Hz",
                color: widget.themeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails(BuildContext context) {
    return ModernCard(
      accentColor: widget.themeColor,
      padding: EdgeInsets.all(UIConsts.spacing2XL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSectionHeader(
            title: "THÔNG SỐ",
            icon: Icons.info_rounded,
            color: widget.themeColor,
          ),
          SizedBox(height: UIConsts.spacingXL),
          _buildDetailRow(
            context,
            "Độ cao (Elevation)",
            "${widget.satellite.elevation.toStringAsFixed(2)}°",
            Icons.height_rounded,
          ),
          ModernDivider(indent: UIConsts.spacingXS, endIndent: UIConsts.spacingXS),
          SizedBox(height: UIConsts.spacingMD),
          _buildDetailRow(
            context,
            "Góc phương vị (Azimuth)",
            "${widget.satellite.azimuth.toStringAsFixed(2)}°",
            Icons.explore_rounded,
          ),
          ModernDivider(indent: UIConsts.spacingXS, endIndent: UIConsts.spacingXS),
          SizedBox(height: UIConsts.spacingMD),
          _buildDetailRow(
            context,
            "Hệ thống",
            widget.satellite.system,
            Icons.language_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        ModernIconContainer(
          icon: icon,
          color: widget.themeColor,
          size: 36,
          iconSize: 18,
        ),
        SizedBox(width: UIConsts.spacingLG),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: context.textSecondaryColor, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}