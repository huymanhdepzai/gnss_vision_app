import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/voice_toggle_switch.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../feedback/presentation/telegram_service.dart';
import 'day_night_scene.dart';

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
  String _appVersion = '';
  String _lastUpdate = '';
  String _cacheSize = '...';
  late AnimationController _themeAnimController;
  late AnimationController _entryController;
  bool _lastIsDark = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _themeAnimController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this, value: 1.0);
    _entryController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..forward();
  }

  @override
  void dispose() {
    _themeAnimController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = 'v${info.version} (${info.buildNumber})');
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
    _loadLastUpdate();
    _calculateCacheSize();
  }

  Future<void> _loadLastUpdate() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await File(dir.path).stat();
      if (mounted) {
        final d = stat.modified;
        setState(() => _lastUpdate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
      }
    } catch (_) {
      try {
        final dir = await getTemporaryDirectory();
        final stat = await File(dir.path).stat();
        if (mounted) {
          final d = stat.modified;
          setState(() => _lastUpdate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
        }
      } catch (_) {
        if (mounted) setState(() => _lastUpdate = '');
      }
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (dir.existsSync()) totalBytes += _calcDirSize(dir);
      if (mounted) setState(() => _cacheSize = _formatBytes(totalBytes));
    } catch (_) {
      if (mounted) setState(() => _cacheSize = 'N/A');
    }
  }

  int _calcDirSize(Directory dir) {
    int total = 0;
    try { for (final e in dir.listSync(recursive: true)) { if (e is File) total += e.lengthSync(); } } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: _a(AppTheme.primaryColor, isDark ? 0.12 : 0.04), blurRadius: 50, spreadRadius: 0, offset: const Offset(8, 0)),
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.06), blurRadius: 25, offset: const Offset(4, 0)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [_a(AppTheme.primaryColor, 0.06), AppTheme.backgroundDark, AppTheme.surfaceDark]
                    : [Colors.white, AppTheme.surfaceLight, _a(AppTheme.cardLight, 0.97)],
              ),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
              border: Border.all(color: isDark ? _a(Colors.white, 0.06) : _a(AppTheme.primaryColor, 0.08), width: 1),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThemeSceneSection(),
                    const SizedBox(height: 16),
                    _accentSection(isDark, AppTheme.primaryColor, [
                      _navItem(context, isDark, Icons.auto_awesome_rounded, 'GNSS-Vision', 'Cảm biến & nhận dạng AI', AppTheme.primaryColor, AppTheme.secondaryColor, widget.onNavigateToVision),
                      _navDivider(isDark),
                      _navItem(context, isDark, Icons.satellite_alt_rounded, 'Vệ Tinh 3D', 'Trạng thái vệ tinh định vị', AppTheme.warningColor, AppTheme.accentColor, widget.onNavigateToSatellite),
                      _navDivider(isDark),
                      _navItem(context, isDark, Icons.route_rounded, 'Chuyến Đi', 'Lịch sử chuyến đi', AppTheme.successColor, const Color(0xFF00E676), () => HapticFeedback.mediumImpact()),
                    ]),
                    const SizedBox(height: 14),
                    _accentSection(isDark, AppTheme.primaryColor, [
                      _sectionHeader(isDark, Icons.tune_rounded, 'Cài đặt', AppTheme.primaryColor),
                      const SizedBox(height: 12),
                      _buildSettingsSection(isDark),
                    ]),
                    const SizedBox(height: 14),
                    _accentSection(isDark, AppTheme.secondaryColor, [
                      _sectionHeader(isDark, Icons.info_outline_rounded, 'Thông tin', AppTheme.secondaryColor),
                      const SizedBox(height: 12),
                      _infoRow(isDark, Icons.verified_rounded, 'Phiên bản', _appVersion.isEmpty ? 'v1.0.0 (1)' : _appVersion, AppTheme.primaryColor, subtitle: _lastUpdate.isEmpty ? null : 'Cập nhật $_lastUpdate'),
                      const SizedBox(height: 10),
                      _infoRow(isDark, Icons.cached_rounded, 'Bộ nhớ đệm', _cacheSize, AppTheme.secondaryColor),
                      _navDivider(isDark),
                      _actionTile(isDark, Icons.shield_outlined, 'Chính sách bảo mật', 'Quyền riêng tư & dữ liệu cá nhân', const Color(0xFF60A5FA), () => _showPrivacyPolicy(isDark)),
                      _navDivider(isDark),
                      _actionTile(isDark, Icons.star_outline_rounded, 'Đánh giá ứng dụng', 'Góp ý & đóng góp cải thiện', AppTheme.warningColor, () => _showRatingDialog(isDark)),
                    ]),
                    const SizedBox(height: 14),
                    _accentSection(isDark, Colors.redAccent, [
                      _navItem(context, isDark, Icons.logout_rounded, 'Đăng xuất', 'Thoát khỏi tài khoản', Colors.redAccent, Colors.orangeAccent, () => _showLogoutDialog(context, isDark)),
                    ]),
                    const SizedBox(height: 16),
                    _buildFooter(isDark),
                  ],
                ),
              ),
            ),
          ),
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
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppTheme.textDark)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
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
              child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSceneSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: DayNightInteractiveScene(
            isDark: themeProvider.isDarkMode,
            onThemeChanged: (isDark) {
              if (isDark != themeProvider.isDarkMode) {
                themeProvider.setThemeMode(isDark);
              }
            },
          ),
        );
      },
    );
  }

  Widget _accentSection(bool isDark, Color accent, List<Widget> children) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? [_a(accent, 0.04), _a(Colors.white, 0.005)] : [_a(accent, 0.025), _a(accent, 0.003)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? _a(Colors.white, 0.06) : _a(accent, 0.08), width: 1),
        boxShadow: [BoxShadow(color: _a(accent, isDark ? 0.05 : 0.02), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _navDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Divider(height: 1, color: isDark ? _a(Colors.white, 0.04) : _a(Colors.black, 0.04)),
    );
  }

  Widget _sectionHeader(bool isDark, IconData icon, String title, Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_a(accent, 0.25), _a(accent, 0.08)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? _a(Colors.white, 0.75) : _a(Colors.black, 0.6))),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [_a(AppTheme.primaryColor, 0.12), _a(AppTheme.secondaryColor, 0.02)]
              : [_a(AppTheme.primaryColor, 0.07), _a(AppTheme.secondaryColor, 0.01)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _a(AppTheme.primaryColor, isDark ? 0.18 : 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: _a(AppTheme.primaryColor, isDark ? 0.18 : 0.06), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: _a(AppTheme.secondaryColor, isDark ? 0.08 : 0.03), blurRadius: 8, offset: const Offset(-3, -3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _a(AppTheme.primaryColor, 0.4), blurRadius: 18, offset: const Offset(0, 4))],
            ),
            child: SvgPicture.asset(
                'assets/branding/icons/icon_foreground.svg',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Text('GNSS VISION', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: isDark ? _a(Colors.white, 0.4) : _a(Colors.black, 0.45), letterSpacing: 0.3),
                  child: const Text('Hệ Thống Di Động Thế Hệ Mới'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, bool isDark, IconData icon, String title, String subtitle, Color accent, Color accentAlt, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.mediumImpact(); Navigator.pop(context); onTap(); },
        borderRadius: BorderRadius.circular(14),
        splashColor: _a(accent, 0.06),
        highlightColor: _a(accent, 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_a(accent, isDark ? 0.22 : 0.15), _a(accentAlt, isDark ? 0.1 : 0.06)]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _a(accent, isDark ? 0.18 : 0.12), width: 1),
                  boxShadow: [BoxShadow(color: _a(accent, isDark ? 0.12 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [accent, accentAlt]).createShader(bounds),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? _a(Colors.white, 0.92) : AppTheme.textDark, letterSpacing: 0.1),
                      child: Text(title),
                    ),
                    const SizedBox(height: 1),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: isDark ? _a(Colors.white, 0.32) : _a(Colors.black, 0.38)),
                      child: Text(subtitle),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? _a(Colors.white, 0.15) : _a(Colors.black, 0.12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    return Consumer2<ThemeProvider, VoiceController>(
      builder: (context, themeProvider, voiceController, _) {
        final d = themeProvider.isDarkMode;
        return Column(
          children: [
            _toggleRow(d, Icons.mic_none_rounded, 'Giọng nói', voiceController.isEnabled, voiceController.isEnabled ? AppTheme.successColor : Colors.grey, const VoiceToggleSwitch(width: 56, height: 28)),
            if (voiceController.isEnabled) ...[
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_a(AppTheme.successColor, d ? 0.08 : 0.04), _a(AppTheme.successColor, d ? 0.02 : 0.005)]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _a(AppTheme.successColor, d ? 0.12 : 0.08), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: _a(AppTheme.successColor, 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Icon(voiceController.isListening ? Icons.graphic_eq_rounded : Icons.info_outline_rounded, size: 13, color: AppTheme.successColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(voiceController.statusMessage, style: TextStyle(color: _a(AppTheme.successColor, 0.8), fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _toggleRow(bool isDark, IconData icon, String label, bool isActive, Color activeColor, Widget toggle) {
    final color = isActive ? activeColor : (isDark ? _a(Colors.white, 0.25) : _a(Colors.black, 0.25));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? _a(activeColor, 0.18) : _a(Colors.grey, isDark ? 0.08 : 0.06), width: 1),
        gradient: isActive ? LinearGradient(colors: [_a(activeColor, isDark ? 0.06 : 0.03), Colors.transparent]) : null,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: isActive ? LinearGradient(colors: [_a(activeColor, isDark ? 0.2 : 0.14), _a(activeColor, isDark ? 0.06 : 0.04)]) : null,
              color: isActive ? null : _a(Colors.grey, isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(color: isDark ? _a(Colors.white, 0.85) : AppTheme.textDark, fontSize: 13.5, fontWeight: FontWeight.w600),
            child: Text(label),
          )),
          toggle,
        ],
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String label, String value, Color accent, {String? subtitle}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _a(accent, isDark ? 0.1 : 0.07), width: 1),
        gradient: LinearGradient(colors: [_a(accent, isDark ? 0.04 : 0.02), Colors.transparent]),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_a(accent, isDark ? 0.2 : 0.14), _a(accent, isDark ? 0.06 : 0.03)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _a(accent, isDark ? 0.15 : 0.1), width: 1),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? _a(Colors.white, 0.65) : _a(Colors.black, 0.55)),
                  child: Text(label),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w400, color: isDark ? _a(Colors.white, 0.3) : _a(Colors.black, 0.35)),
                    child: Text(subtitle),
                  ),
                ],
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_a(accent, isDark ? 0.14 : 0.08), _a(accent, isDark ? 0.06 : 0.02)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _a(accent, isDark ? 0.12 : 0.08)),
            ),
            child: Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'RobotoMono', color: _a(accent, isDark ? 0.9 : 0.7))),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(bool isDark, IconData icon, String title, String subtitle, Color accent, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.mediumImpact(); Navigator.pop(context); onTap(); },
        borderRadius: BorderRadius.circular(14),
        splashColor: _a(accent, 0.06),
        highlightColor: _a(accent, 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_a(accent, isDark ? 0.22 : 0.15), _a(accent, isDark ? 0.08 : 0.04)]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _a(accent, isDark ? 0.18 : 0.12), width: 1),
                  boxShadow: [BoxShadow(color: _a(accent, isDark ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? _a(Colors.white, 0.92) : AppTheme.textDark, letterSpacing: 0.1),
                      child: Text(title),
                    ),
                    const SizedBox(height: 1),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: isDark ? _a(Colors.white, 0.32) : _a(Colors.black, 0.38)),
                      child: Text(subtitle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, isDark ? _a(Colors.white, 0.06) : _a(AppTheme.primaryColor, 0.07), Colors.transparent]))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/branding/icons/icon_monochrome.svg',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(isDark ? _a(Colors.white, 0.2) : _a(Colors.black, 0.2), BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: isDark ? _a(Colors.white, 0.2) : _a(Colors.black, 0.2), letterSpacing: 0.5),
                child: const Text('GNSS Vision  ·  © 2025'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_a(const Color(0xFF60A5FA), 0.2), _a(const Color(0xFF3B82F6), 0.08)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text('Chính Sách Bảo Mật', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppTheme.textDark))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _policyItem(isDark, Icons.location_on_rounded, 'Vị trí', 'Dữ liệu vị trí chỉ dùng cho định vị & điều hướng. Không chia sẻ bên thứ ba.'),
              const SizedBox(height: 12),
              _policyItem(isDark, Icons.camera_alt_rounded, 'Camera', 'Chỉ hoạt động khi bật GNSS-Vision. Không tự động chụp hay lưu ảnh.'),
              const SizedBox(height: 12),
              _policyItem(isDark, Icons.storage_rounded, 'Dữ liệu', 'Dữ liệu chuyến đi lưu cục bộ trên thiết bị. Không đồng bộ máy chủ.'),
              const SizedBox(height: 12),
              _policyItem(isDark, Icons.mic_rounded, 'Giọng nói', 'Xử lý trên thiết bị. Không ghi âm hay truyền dữ liệu âm thanh.'),
            ],
          ),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
              child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyItem(bool isDark, IconData icon, String title, String desc) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _a(AppTheme.primaryColor, isDark ? 0.06 : 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _a(AppTheme.primaryColor, isDark ? 0.1 : 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_a(AppTheme.primaryColor, isDark ? 0.2 : 0.12), _a(AppTheme.primaryColor, isDark ? 0.08 : 0.03)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppTheme.textDark)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 12.5, height: 1.45, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(bool isDark) {
    int stars = 0;
    bool isSubmitting = false;
    TextEditingController commentController = TextEditingController();
    final parentMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting, // Chống việc bấm ra ngoài khi đang gửi
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_a(AppTheme.warningColor, 0.2), _a(AppTheme.warningColor, 0.05)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 34),
              ),
              const SizedBox(height: 12),
              Text('Đánh Giá Ứng Dụng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppTheme.textDark)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cảm ơn bạn đã sử dụng GNSS Vision!', style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white60 : Colors.black54), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: isSubmitting ? null : () => setState(() => stars = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < stars ? AppTheme.warningColor : (isDark ? Colors.white24 : Colors.black12),
                        size: 38,
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 10),
                Text(
                  stars == 0 ? 'Chạm để đánh giá' : stars <= 3 ? 'Cần cải thiện' : stars == 4 ? 'Tốt!' : 'Tuyệt vời!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: stars == 0 ? (isDark ? Colors.white38 : Colors.black38) : AppTheme.warningColor),
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    enabled: !isSubmitting,
                    maxLines: 3,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nhập góp ý của bạn...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? _a(Colors.white, 0.05) : _a(Colors.black, 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  )
                ]
              ],
            ),
          ),
          actions: [
            if (!isSubmitting)
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Để sau', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500))
              ),
            Container(
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                onPressed: (stars > 0 && !isSubmitting) ? () async {
                  setState(() => isSubmitting = true);

                  try {
                    final success = await TelegramService.sendFeedback(
                      stars: stars,
                      comment: commentController.text,
                      version: _appVersion,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }

                    parentMessenger.showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Cảm ơn bạn đã gửi đánh giá!' : 'Có lỗi xảy ra, vui lòng thử lại.'),
                        backgroundColor: success ? AppTheme.successColor : AppTheme.warningColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );

                  } catch (e) {
                    if (ctx.mounted) {
                      setState(() => isSubmitting = false);
                    }
                    parentMessenger.showSnackBar(
                      SnackBar(
                          content: Text('Lỗi hệ thống: $e'),
                          backgroundColor: AppTheme.warningColor
                      ),
                    );
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                ),
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Gửi đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}