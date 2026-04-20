import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/theme_toggle_switch.dart';
import '../../../../shared/widgets/voice_toggle_switch.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../vision/presentation/pages/satellite_page.dart';
import '../../../vision/presentation/pages/flow_page.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onNavigateToVision;
  final VoidCallback onNavigateToSatellite;

  const AppDrawer({
    Key? key,
    required this.onNavigateToVision,
    required this.onNavigateToSatellite,
  }) : super(key: key);

  Color _adow(bool isDark, Color color, double opacity) {
    return isDark
        ? color.withOpacity(opacity)
        : color.withOpacity(opacity * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final size = MediaQuery.of(context).size;

        return Drawer(
          backgroundColor: Colors.transparent,
          elevation: 0,
          width: size.width * 0.82,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(8, 0),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                  blurRadius: 25,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppTheme.primaryColor.withOpacity(0.12),
                              AppTheme.backgroundDark.withOpacity(0.97),
                              AppTheme.surfaceDark.withOpacity(0.95),
                            ]
                          : [
                              Colors.white.withOpacity(0.97),
                              AppTheme.surfaceLight.withOpacity(0.98),
                              AppTheme.cardLight.withOpacity(0.95),
                            ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(32),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : AppTheme.primaryColor.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 8),
                        _buildDivider(isDark),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            "CHỨC NĂNG",
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.secondaryColor.withOpacity(0.6)
                                  : AppTheme.primaryColor.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildNavItem(
                          context: context,
                          isDark: isDark,
                          icon: Icons.auto_awesome_rounded,
                          title: "GNSS-Vision",
                          subtitle: "Cảm biến & nhận dạng AI",
                          primaryColor: AppTheme.primaryColor,
                          secondaryColor: AppTheme.secondaryColor,
                          onTap: onNavigateToVision,
                        ),
                        _buildNavItem(
                          context: context,
                          isDark: isDark,
                          icon: Icons.satellite_alt_rounded,
                          title: "Vệ Tinh 3D",
                          subtitle: "Trạng thái vệ tinh định vị",
                          primaryColor: AppTheme.warningColor,
                          secondaryColor: AppTheme.accentColor,
                          onTap: onNavigateToSatellite,
                        ),
                        _buildNavItem(
                          context: context,
                          isDark: isDark,
                          icon: Icons.route_rounded,
                          title: "Chuyến Đi",
                          subtitle: "Quản lý lịch sử chuyến đi",
                          primaryColor: AppTheme.successColor,
                          secondaryColor: const Color(0xFF00E676),
                          onTap: () {
                            Navigator.pop(context);
                            HapticFeedback.mediumImpact();
                          },
                        ),
                        const Spacer(),
                        _buildDivider(isDark),
                        _buildFooter(context, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  Colors.transparent,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(isDark ? 0.5 : 0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(
                    isDark ? 0.3 : 0.15,
                  ),
                  blurRadius: 12,
                  offset: const Offset(-2, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    "GNSS VISION",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Hệ Thống Di Động Thế Hệ Mới",
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppTheme.primaryColor.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: primaryColor.withOpacity(0.1),
          highlightColor: primaryColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : primaryColor.withOpacity(0.08),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.01),
                      ]
                    : [
                        primaryColor.withOpacity(0.04),
                        primaryColor.withOpacity(0.01),
                      ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withOpacity(isDark ? 0.2 : 0.15),
                        secondaryColor.withOpacity(isDark ? 0.1 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(isDark ? 0.25 : 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: secondaryColor.withOpacity(isDark ? 0.1 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, secondaryColor],
                    ).createShader(bounds),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.35)
                              : Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : primaryColor.withOpacity(0.35),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Consumer2<ThemeProvider, VoiceController>(
      builder: (context, themeProvider, voiceController, child) {
        final isDark2 = themeProvider.isDarkMode;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            children: [
              _buildToggleRow(
                isDark: isDark2,
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.nightlight_round,
                label: "Giao diện",
                isActive: isDark2,
                color: AppTheme.primaryColor,
                toggle: const ThemeToggleSwitch(width: 64, height: 32),
              ),
              const SizedBox(height: 14),
              _buildToggleRow(
                isDark: isDark2,
                icon: Icons.mic_off_outlined,
                activeIcon: Icons.mic,
                label: "Giọng Nói",
                isActive: voiceController.isEnabled,
                color: voiceController.isEnabled
                    ? AppTheme.successColor
                    : Colors.grey,
                toggle: const VoiceToggleSwitch(width: 64, height: 32),
              ),
              if (voiceController.isEnabled) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successColor.withOpacity(isDark2 ? 0.1 : 0.06),
                        AppTheme.successColor.withOpacity(
                          isDark2 ? 0.04 : 0.02,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(
                        isDark2 ? 0.2 : 0.15,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        voiceController.isListening
                            ? Icons.record_voice_over_rounded
                            : Icons.info_outline_rounded,
                        size: 13,
                        color: AppTheme.successColor.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          voiceController.statusMessage,
                          style: TextStyle(
                            color: AppTheme.successColor.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleRow({
    required bool isDark,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required Color color,
    required Widget toggle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [color.withOpacity(0.2), color.withOpacity(0.06)]
                  : [
                      Colors.grey.withOpacity(0.1),
                      Colors.grey.withOpacity(0.03),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? color.withOpacity(isDark ? 0.25 : 0.2)
                  : Colors.grey.withOpacity(isDark ? 0.1 : 0.15),
              width: 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(isDark ? 0.15 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? color
                : (isDark ? Colors.white38 : Colors.black38),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.85)
                  : AppTheme.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        toggle,
      ],
    );
  }
}
