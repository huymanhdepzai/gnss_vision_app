import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../controllers/flow_controller.dart';
import '../../../../core/providers/theme_provider.dart';
import '../widgets/flow_painter.dart';

class FlowScreenV2 extends StatefulWidget {
  const FlowScreenV2({Key? key}) : super(key: key);

  @override
  State<FlowScreenV2> createState() => _FlowScreenV2State();
}

class _FlowScreenV2State extends State<FlowScreenV2>
    with TickerProviderStateMixin {
  final FlowController _controller = FlowController();
  bool _isDebugMode = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _controller.init();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: UIConsts.animEntrance,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: UIConsts.curveEntrance),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: AppTheme.adaptiveBackground(isDark),
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoBackground(isDark),
              _buildHeadingIndicator(isDark),
              _buildBottomDashboard(topPadding, bottomPadding, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeadingIndicator(bool isDark) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: _controller.frameNotifier,
      builder: (context, frame, child) {
        if (frame == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 180,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: _controller.headingNotifier,
                builder: (context, heading, child) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _controller.turnIntensityNotifier,
                    builder: (context, turnIntensity, child) {
                      return SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: DirectionArrowPainter(
                            heading: heading,
                            primaryColor: AppTheme.primaryColor,
                            accentColor: AppTheme.secondaryColor,
                            confidence: 0.85,
                            turnIntensity: turnIntensity,
                            showPath: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoBackground(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.frameNotifier,
      builder: (context, bytes, child) {
        if (bytes != null && _controller.imageSize != Size.zero) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
              ),
            ),
            child: Center(
              child: RepaintBoundary(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.imageSize.width,
                    height: _controller.imageSize.height,
                    child: Stack(
                      children: [
                        Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                          ValueListenableBuilder(
                          valueListenable: _controller.headingNotifier,
                          builder: (context, heading, _) {
                            return ValueListenableBuilder<List<Rect>>(
                              valueListenable: _controller.aiObstaclesNotifier,
                              builder: (context, obstacles, _) {
                                return Positioned.fill(
                                  child: CustomPaint(
                                    painter: FlowPainter(
                                      points: _controller.pointsToDraw,
                                      imageSize: _controller.imageSize,
                                      staticRois: _controller.staticRois,
                                      aiObstacles: obstacles,
                                      isDebugMode: _isDebugMode,
                                      confidence: null,
                                      moveVector: null,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return _buildPlaceholder(isDark);
      },
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedLogo(isDark),
            const SizedBox(height: UIConsts.spacing4XL),
            Text(
              "VISION FLOW",
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: UIConsts.spacingMD),
            Text(
              "Hệ thống phân tích hành trình thông minh",
              style: TextStyle(
                color: AppTheme.adaptiveSubtext(isDark),
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),
            _buildStartButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo(bool isDark) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3 * _glowController.value),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: AppTheme.glowDecoration(
                AppTheme.secondaryColor,
                radius: 40,
              ),
              child: const Icon(
                Icons.auto_awesome_motion_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartButton(bool isDark) {
    return GestureDetector(
      onTap: _controller.pickAndPlayVideo,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: AppTheme.gradientButtonDecoration(
              gradient: AppTheme.primaryGradient,
              isDark: isDark,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  "BẮT ĐẦU NGAY",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomDashboard(double topPadding, double bottomPadding, bool isDark) {
    return Positioned(
      left: UIConsts.spacingLG,
      right: UIConsts.spacingLG,
      bottom: bottomPadding + UIConsts.spacingLG,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: UIConsts.spacingLG, vertical: UIConsts.spacingMD),
          decoration: AppTheme.glassDecoration(isDark: isDark),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactProgressBar(isDark),
              const SizedBox(height: UIConsts.spacingMD),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- Group 1: Speed ---
                  _buildDashboardInfo(isDark),
                  
                  // --- Group 2: Primary Control (Center) ---
                  _buildMainPlayButton(isDark),
                  
                  // --- Group 3: Options Menu ---
                  _buildOptionsMenu(isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsMenu(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : AppTheme.textDark.withOpacity(0.7)),
      ),
      offset: const Offset(0, -180),
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        HapticFeedback.lightImpact();
        switch (value) {
          case 'pick': _controller.pickAndPlayVideo(); break;
          case 'voice': _controller.toggleVoice(); break;
          case 'debug': setState(() => _isDebugMode = !_isDebugMode); break;
          case 'reset': _controller.resetTracking(); break;
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem('pick', Icons.video_library_rounded, "Chọn Video", isDark),
        _buildPopupItem(
          'voice', 
          _controller.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, 
          "Giọng nói: ${_controller.voiceEnabled ? 'Bật' : 'Tắt'}", 
          isDark,
          color: _controller.voiceEnabled ? AppTheme.successColor : null,
        ),
        _buildPopupItem(
          'debug', 
          _isDebugMode ? Icons.grid_view_rounded : Icons.grid_off_rounded, 
          "Debug Mode: ${_isDebugMode ? 'Bật' : 'Tắt'}", 
          isDark,
          color: _isDebugMode ? AppTheme.secondaryColor : null,
        ),
        const PopupMenuDivider(),
        _buildPopupItem('reset', Icons.refresh_rounded, "Làm mới theo dõi", isDark),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, bool isDark, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color ?? (isDark ? Colors.white70 : AppTheme.textDark.withOpacity(0.7)), size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isDark ? Colors.white : AppTheme.textDark, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDashboardInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _controller.speedNotifier,
          builder: (context, speed, _) {
            final displaySpeed = _controller.isDemoMode ? "60" : (speed * 3.6).toStringAsFixed(0);
            return Text(
              displaySpeed,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            );
          },
        ),
        Text(
          "KM/H",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryColor.withOpacity(0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardStatus(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIndicator(
              icon: Icons.gps_fixed_rounded,
              isActive: _controller.hasValidGps,
              activeColor: AppTheme.successColor,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildStatusIndicator(
              icon: Icons.psychology_rounded,
              isActive: _controller.isModelLoaded,
              activeColor: AppTheme.secondaryColor,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: isActive ? activeColor : AppTheme.adaptiveSubtext(isDark).withOpacity(0.4),
        size: 18,
      ),
    );
  }

  Widget _buildCompactProgressBar(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.progressNotifier,
      builder: (context, progress, child) {
        final total = _controller.totalFrames > 0 ? _controller.totalFrames : 1.0;
        final ratio = (progress / total).clamp(0.0, 1.0);

        return Container(
          width: double.infinity,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinIconButton(IconData icon, VoidCallback onTap, bool isDark, {bool active = false, Color? color}) {
    final effectiveColor = color ?? (isDark ? Colors.white : AppTheme.textDark);
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      icon: Icon(
        icon,
        color: active ? (color ?? AppTheme.secondaryColor) : effectiveColor.withOpacity(0.5),
        size: 22,
      ),
    );
  }

  Widget _buildMainPlayButton(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _controller.togglePause();
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: AppTheme.glowDecoration(
              _controller.isPaused ? AppTheme.primaryColor : AppTheme.secondaryColor,
              radius: 28,
            ),
            child: Icon(
              _controller.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }
}
