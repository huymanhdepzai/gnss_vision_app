import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/modern_toggle_switch.dart';
import '../pages/settings_page.dart';


import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback onNavigateToVision;
  final VoidCallback onNavigateToSatellite;

  const AppDrawer({
    super.key,
    required this.onNavigateToVision,
    required this.onNavigateToSatellite,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  late AnimationController _themeAnimController;
  late AnimationController _entryController;
  bool _lastIsDark = true;

  @override
  void initState() {
    super.initState();
    _themeAnimController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this, value: 1.0);
    _entryController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..forward();
  }

  @override
  void dispose() {
    _themeAnimController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _onThemeChanged(bool isDark) {
    if (_lastIsDark != isDark) { _lastIsDark = isDark; _themeAnimController.forward(from: 0); }
  }

  Color _a(Color c, double o) => c.withOpacity(o);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        _onThemeChanged(isDark);
        return AnimatedBuilder(
          animation: Listenable.merge([_themeAnimController, _entryController]),
          builder: (context, _) {
            final et = Curves.easeOutCubic.transform(_entryController.value);
            return Drawer(
              backgroundColor: Colors.transparent,
              elevation: 0,
              width: MediaQuery.of(context).size.width * 0.82,
              child: Transform.translate(
                offset: Offset(-(1 - et) * 60, 0),
                child: Opacity(opacity: et, child: _buildBody(isDark)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 40,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppTheme.backgroundDark.withOpacity(0.85) 
                  : Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
              border: Border.all(
                color: isDark ? Colors.white10 : AppTheme.primaryColor.withOpacity(0.05),
                width: 1.5,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return state.maybeWhen(
                        authenticated: (user, isBio) => _buildHeader(isDark, user.displayName, user.photoUrl),
                        orElse: () => _buildHeader(isDark, 'Người dùng', null),
                      );
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _navItem(context, isDark, 'assets/icons/position.svg', 'GNSS-Vision', widget.onNavigateToVision),
                          _divider(isDark),
                          _navItem(context, isDark, 'assets/icons/satellite.svg', 'Vệ Tinh 3D', widget.onNavigateToSatellite),
                          _biometricToggle(context, isDark),
                          _navItem(
                            context, 
                            isDark, 
                            'assets/icons/setting.svg', 
                            'Cài đặt', 
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))
                          ),
                          _divider(isDark),
                          _navItem(
                            context, 
                            isDark, 
                            'assets/icons/logout.svg', 
                            'Đăng xuất', 
                            () => _showLogoutDialog(context, isDark),
                            isLogout: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _biometricToggle(BuildContext context, bool isDark) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isBiometricEnabled = state.maybeWhen(
          authenticated: (_, enabled) => enabled,
          unauthenticated: (enabled) => enabled,
          orElse: () => false,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.fingerprint_rounded,
                size: 24,
                color: isDark ? Colors.white.withOpacity(0.7) : AppTheme.primaryColor,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Sinh trắc học',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textDark,
                  ),
                ),
              ),
              ModernToggleSwitch(
                value: isBiometricEnabled,
                onChanged: (enabled) {
                  context.read<AuthBloc>().add(AuthEvent.toggleBiometricRequested(enabled));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String? name, String? photoUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.white,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: photoUrl != null
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name ?? 'Khách',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Thành viên GNSS',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.primaryColor.withOpacity(0.6),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(bool isDark, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white24 : Colors.black26,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, bool isDark, String svgPath, String title, VoidCallback onTap, {bool isLogout = false}) {
    final iconColor = isLogout
        ? Colors.white
        : (isDark ? Colors.white.withOpacity(0.7) : AppTheme.primaryColor);

    final bgColor = isLogout
        ? AppTheme.primaryColor
        : Colors.transparent;

    return Container(
      margin: isLogout ? const EdgeInsets.symmetric(vertical: 8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isLogout ? BorderRadius.circular(0) : BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (title != 'Cài đặt') Navigator.pop(context);
            onTap();
          },
          borderRadius: isLogout ? BorderRadius.circular(0) : BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: isLogout ? 16 : 18
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  svgPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                const SizedBox(width: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isLogout ? FontWeight.w700 : FontWeight.w600,
                    color: isLogout
                        ? Colors.white
                        : (isDark ? Colors.white.withOpacity(0.9) : AppTheme.textDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Text(
        'Phiên bản 1.0.0',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white10 : Colors.black12,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/logout.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.redAccent, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppTheme.textDark)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn đăng xuất không?', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.redAccent, Color(0xFFFF5252)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                ctx.read<AuthBloc>().add(const AuthEvent.logoutRequested());
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
