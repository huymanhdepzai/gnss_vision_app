import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/page_transitions.dart';
import '../controllers/flow_controller.dart';
import '../controllers/theme_provider.dart';
import '../widgets/flow_painter.dart';
import 'dart:ui' as ui;

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
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _controller.init();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDark
              ? AppTheme.backgroundDark
              : AppTheme.backgroundLight,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoBackground(isDark),
              _buildAmbientEffects(isDark),
              _buildAROverlay(),
              _buildTopPanel(topPadding, isDark),
              _buildBottomPanel(isDark),
              _buildCompassOverlay(isDark),
            ],
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
          return Center(
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
                        filterQuality: FilterQuality.low,
                      ),
                      CustomPaint(
                        painter: FlowPainter(
                          points: _controller.pointsToDraw,
                          imageSize: _controller.imageSize,
                          staticRois: _controller.staticRois,
                          aiObstacles: _controller.aiObstacles,
                          isDebugMode: _isDebugMode,
                        ),
                      ),
                    ],
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
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.7);
    final hintColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.5);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(
                          0.3 * _glowController.value,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: hintColor,
                    size: 80,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              "Ready to Stream",
              style: TextStyle(
                color: subtextColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Select a video to begin analysis",
              style: TextStyle(
                color: hintColor,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 40),
            _buildSelectVideoButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectVideoButton() {
    return GestureDetector(
      onTap: _controller.pickAndPlayVideo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Text(
              "CHỌN NGUỒN VIDEO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientEffects(bool isDark) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.secondaryColor.withOpacity(
                        0.1 * _glowController.value,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Positioned(
              bottom: 100,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(
                        0.1 * (1 - _glowController.value),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAROverlay() {
    return ValueListenableBuilder(
      valueListenable: _controller.headingNotifier,
      builder: (context, heading, child) {
        if (_controller.frameNotifier.value == null)
          return const SizedBox.shrink();
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCompassOverlay(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.headingNotifier,
      builder: (context, heading, child) {
        if (_controller.frameNotifier.value == null)
          return const SizedBox.shrink();

        final bgGradient = isDark
            ? [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.3)]
            : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.7)];

        return Positioned(
          bottom: 200,
          right: 24,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_pulseController.value * 0.05),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: bgGradient,
                    ),
                    border: Border.all(
                      color: AppTheme.secondaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: -5,
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.transparent
                            : Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedRotation(
                        turns: heading / 360.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.navigation_rounded,
                            color: AppTheme.accentColor,
                            size: 40,
                          ),
                        ),
                      ),
                      ...List.generate(4, (index) {
                        return Transform.rotate(
                          angle: (index * 90) * pi / 180,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Container(
                                height: 6,
                                width: 2,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopPanel(double topPadding, bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.5);
    final bordercolor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);
    final bgColors = isDark
        ? [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.2)]
        : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.65)];

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bgColors,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: bordercolor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.transparent
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildStatItem(
                      label: "TỐC ĐỘ",
                      value: _controller.isDemoMode
                          ? "DEMO"
                          : "${(_controller.speedNotifier.value * 3.6).toStringAsFixed(0)}",
                      unit: "KM/H",
                      color: AppTheme.secondaryColor,
                      icon: Icons.speed_rounded,
                      isDark: isDark,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    _buildStatItem(
                      label: "HƯỚNG",
                      value:
                          "${headingNotifierValue(_controller.headingNotifier).toStringAsFixed(0)}°",
                      unit: _getDirectionString(
                        headingNotifierValue(_controller.headingNotifier),
                      ),
                      color: AppTheme.primaryColor,
                      icon: Icons.explore_rounded,
                      isDark: isDark,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    Expanded(child: _buildSystemIndicators(isDark)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double headingNotifierValue(ValueNotifier<double> notifier) {
    return notifier.value;
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.5);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 12),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(color: color.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemIndicators(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildIndicatorIcon(
                  icon: Icons.satellite_alt_rounded,
                  isActive: _controller.hasValidGps,
                  activeColor: AppTheme.successColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildIndicatorIcon(
                  icon: Icons.psychology_rounded,
                  isActive: _controller.isModelLoaded,
                  activeColor: AppTheme.secondaryColor,
                  isLoading: !_controller.isModelLoaded,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _controller.isModelLoaded
                    ? AppTheme.successColor.withOpacity(0.2)
                    : AppTheme.warningColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _controller.isModelLoaded ? "AI ACTIVE" : "AI LOADING",
                style: TextStyle(
                  color: _controller.isModelLoaded
                      ? AppTheme.successColor.withOpacity(0.8)
                      : AppTheme.warningColor.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIndicatorIcon({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(activeColor),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.2)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(
                        0.3 * _pulseController.value,
                      ),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive
                ? activeColor
                : (isDark ? Colors.white24 : Colors.black26),
            size: 16,
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: _controller.progressNotifier,
              builder: (context, progress, child) {
                return _buildProgressBar(progress, isDark);
              },
            ),
            const SizedBox(height: 16),
            _buildControlsPanel(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool isDark) {
    final textColor = isDark
        ? Colors.white.withOpacity(0.5)
        : Colors.black.withOpacity(0.6);
    final bgColors = isDark
        ? [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.2)]
        : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)];
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _controller.formatTime(progress, _controller.fps),
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _controller.formatTime(
                  _controller.totalFrames,
                  _controller.fps,
                ),
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.secondaryColor,
              inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
              thumbColor: isDark ? Colors.white : AppTheme.primaryColor,
              overlayColor: AppTheme.secondaryColor.withOpacity(0.3),
            ),
            child: Slider(
              value: progress.clamp(
                0.0,
                _controller.totalFrames > 0 ? _controller.totalFrames : 1.0,
              ),
              min: 0.0,
              max: _controller.totalFrames > 0 ? _controller.totalFrames : 1.0,
              onChanged: (val) {
                _controller.progressNotifier.value = val;
                _controller.seekTo(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(bool isDark) {
    final bgColor = isDark
        ? [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.4)]
        : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)];
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgColor,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.transparent
                    : Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.folder_copy_rounded,
                    onTap: _controller.pickAndPlayVideo,
                    isDark: isDark,
                  ),
                  _buildControlButton(
                    icon: _isDebugMode
                        ? Icons.grid_view_rounded
                        : Icons.grid_view_outlined,
                    color: _isDebugMode
                        ? AppTheme.secondaryColor
                        : (isDark ? Colors.white54 : Colors.black54),
                    onTap: () => setState(() => _isDebugMode = !_isDebugMode),
                    isDark: isDark,
                  ),
                  _buildPlayButton(),
                  _buildSpeedButton(isDark),
                  _buildControlButton(
                    icon: Icons.refresh_rounded,
                    onTap: _controller.resetTracking,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: color ?? (isDark ? Colors.white70 : Colors.black54),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _controller.togglePause();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _controller.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildSpeedButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_controller.isPlaying) _controller.cycleSpeed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          "${_controller.playbackSpeed}x",
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _getDirectionString(double heading) {
    if (heading >= 337.5 || heading < 22.5) return "N";
    if (heading >= 22.5 && heading < 67.5) return "NE";
    if (heading >= 67.5 && heading < 112.5) return "E";
    if (heading >= 112.5 && heading < 157.5) return "SE";
    if (heading >= 157.5 && heading < 202.5) return "S";
    if (heading >= 202.5 && heading < 247.5) return "SW";
    if (heading >= 247.5 && heading < 292.5) return "W";
    if (heading >= 292.5 && heading < 337.5) return "NW";
    return "N/A";
  }
}
