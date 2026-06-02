import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/voice_toggle_switch.dart';
import '../../../../shared/widgets/modern_toggle_switch.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../feedback/presentation/telegram_service.dart';
import '../widgets/day_night_scene.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';
  String _lastUpdate = '';
  String _cacheSize = '...';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
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
    try {
      for (final e in dir.listSync(recursive: true)) {
        if (e is File) total += e.lengthSync();
      }
    } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _a(Color c, double o) => c.withOpacity(o);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppTheme.textDark,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DayNightInteractiveScene(
                isDark: isDark,
                onThemeChanged: (v) => themeProvider.setThemeMode(v),
              ),
            ),
            
            _sectionTitle('ỨNG DỤNG'),
            _buildSettingsList(context, isDark),
            
            const SizedBox(height: 24),
            _sectionTitle('THÔNG TIN'),
            _buildInfoList(isDark),
            
            const SizedBox(height: 32),
            Center(
              child: Text(
                'GNSS Vision $_appVersion',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return _listContainer(isDark, [
      _settingRow(
        isDark,
        Icons.color_lens_outlined,
        'Giao diện',
        isDark,
        onChanged: (v) => themeProvider.setThemeMode(v),
        activeToggleIcon: Icons.nightlight_round,
        inactiveToggleIcon: Icons.wb_sunny_rounded,
        activeColor: const Color(0xFF90CAF9),
      ),
      Consumer<VoiceController>(
        builder: (context, voiceController, _) => _settingRow(
          isDark,
          Icons.mic_rounded,
          'Trợ lý giọng nói',
          voiceController.isEnabled,
          onChanged: (v) => voiceController.toggleEnabled(),
          activeToggleIcon: Icons.mic,
          inactiveToggleIcon: Icons.mic_off,
          activeColor: AppTheme.successColor,
        ),
      ),
      _navRow(isDark, Icons.shield_moon_rounded, 'Chính sách bảo mật', () => _showPrivacyPolicy(context, isDark)),
      _navRow(isDark, Icons.star_rounded, 'Đánh giá ứng dụng', () => _showRatingDialog(context, isDark)),
    ]);
  }

  Widget _buildInfoList(bool isDark) {
    return _listContainer(isDark, [
      // _infoItem('Phiên bản', _appVersion),
      _infoItem('Cập nhật', _lastUpdate.isEmpty ? 'Mới nhất' : _lastUpdate),
      _infoItem('Bộ nhớ đệm', _cacheSize),
    ]);
  }

  Widget _listContainer(bool isDark, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _settingRow(
    bool isDark, 
    IconData icon, 
    String title, 
    bool value, {
    required ValueChanged<bool> onChanged,
    IconData activeToggleIcon = Icons.check,
    IconData inactiveToggleIcon = Icons.close,
    Color? activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isDark ? Colors.white60 : Colors.black45),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textDark,
              ),
            ),
          ),
          ModernToggleSwitch(
            value: value,
            onChanged: onChanged,
            activeIcon: activeToggleIcon,
            inactiveIcon: inactiveToggleIcon,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }

  Widget _navRow(bool isDark, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? Colors.white60 : Colors.black45),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white24 : Colors.black12),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Chính Sách Bảo Mật', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _policyItem(isDark, Icons.location_on_rounded, 'Vị trí', 'Dữ liệu vị trí chỉ dùng cho định vị & điều hướng.'),
              const SizedBox(height: 12),
              _policyItem(isDark, Icons.camera_alt_rounded, 'Camera', 'Chỉ hoạt động khi bật GNSS-Vision.'),
              const SizedBox(height: 12),
              _policyItem(isDark, Icons.storage_rounded, 'Dữ liệu', 'Dữ liệu chuyến đi lưu cục bộ trên thiết bị.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
        ],
      ),
    );
  }

  Widget _policyItem(bool isDark, IconData icon, String title, String desc) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  void _showRatingDialog(BuildContext context, bool isDark) {
    int stars = 0;
    bool isSubmitting = false;
    TextEditingController commentController = TextEditingController();
    final parentMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Đánh Giá Ứng Dụng', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setState(() => stars = i + 1),
                  icon: Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: AppTheme.warningColor, size: 32),
                )),
              ),
              if (stars > 0)
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(hintText: 'Góp ý của bạn...'),
                  maxLines: 2,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: stars == 0 ? null : () async {
                setState(() => isSubmitting = true);
                final success = await TelegramService.sendFeedback(
                  stars: stars,
                  comment: commentController.text,
                  version: _appVersion,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                parentMessenger.showSnackBar(SnackBar(content: Text(success ? 'Cảm ơn bạn!' : 'Lỗi gửi đánh giá.')));
              },
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }
}
