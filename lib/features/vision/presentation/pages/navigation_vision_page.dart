import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../controllers/flow_controller.dart';
import '../widgets/flow_painter.dart';
import '../widgets/navigation_map_widget.dart';
import '../widgets/turn_instruction_card.dart';
import '../../../map/presentation/controllers/navigation_controller.dart';

class NavigationVisionPage extends StatefulWidget {
  const NavigationVisionPage({super.key});

  @override
  State<NavigationVisionPage> createState() => _NavigationVisionPageState();
}

class _NavigationVisionPageState extends State<NavigationVisionPage>
    with TickerProviderStateMixin {
  final FlowController _flowController = FlowController();
  bool _isDebugMode = false;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _entryController;
  late AnimationController _dividerController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _entryFadeAnimation;
  late Animation<Offset> _entrySlideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _dividerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _entrySlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _entryController.forward();
    _flowController.init();

    SystemChrome.setPreferredOrientations([]);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _entryController.dispose();
    _dividerController.dispose();
    _shimmerController.dispose();
    _flowController.dispose();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 600;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF060A18)
              : AppTheme.backgroundLight,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  flex: 55,
                  child: _buildVideoSection(isDark, isSmallDevice),
                ),
                _buildDivider(),
                Expanded(
                  flex: 45,
                  child: _buildMapSection(isDark, isSmallDevice),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return AnimatedBuilder(
      animation: _dividerController,
      builder: (context, child) {
        final offset = _dividerController.value;
        return Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.transparent,
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.primaryColor,
                Colors.transparent,
              ],
              stops: [
                0.0,
                (0.25 + offset * 0.25).clamp(0.0, 1.0),
                (0.5 + offset * 0.0).clamp(0.0, 1.0),
                (0.75 - offset * 0.25).clamp(0.0, 1.0),
                1.0,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoSection(bool isDark, bool isSmallDevice) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoBackground(isDark),
        _buildAmbientEffects(),
        Positioned(
          top: 4,
          left: 6,
          right: 6,
          child: _buildTopPanel(isDark, isSmallDevice),
        ),
        _buildTurnInstruction(isSmallDevice),
        Positioned(
          bottom: 4,
          right: 6,
          child: _buildMiniControls(isDark, isSmallDevice),
        ),
      ],
    );
  }

  Widget _buildVideoBackground(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _flowController.frameNotifier,
      builder: (context, bytes, child) {
        if (bytes != null && _flowController.imageSize != Size.zero) {
          return Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: RepaintBoundary(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _flowController.imageSize.width,
                    height: _flowController.imageSize.height,
                    child: Stack(
                      children: [
                        Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                        ValueListenableBuilder(
                          valueListenable: _flowController.headingNotifier,
                          builder: (context, heading, _) {
                            return CustomPaint(
                              painter: FlowPainter(
                                points: _flowController.pointsToDraw,
                                imageSize: _flowController.imageSize,
                                staticRois: _flowController.staticRois,
                                aiObstacles: _flowController.aiObstacles,
                                isDebugMode: _isDebugMode,
                                confidence: null,
                                moveVector: null,
                              ),
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
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowVal = _glowController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF060A18),
                      AppTheme.surfaceDark,
                      const Color(0xFF0A0F28),
                      const Color(0xFF060A18),
                    ]
                  : [
                      AppTheme.backgroundLight,
                      AppTheme.surfaceLight,
                      const Color(0xFFF0F4FA),
                      AppTheme.backgroundLight,
                    ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
            animation: Listenable.merge([_glowController, _pulseController]),
            builder: (context, child) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.4 * _glowController.value),
                      AppTheme.secondaryColor.withOpacity(
                        0.2 * _pulseController.value,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(
                        0.3 * _pulseController.value,
                      ),
                      blurRadius: 40 + (_pulseController.value * 20),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ],
                ),
              );
            },
          ),
                const SizedBox(height: 25),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'GNSS Vision',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 3.5,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                _buildSelectVideoButton(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmbientEffects() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowVal = _glowController.value;
            return Stack(
              children: [
                Positioned(
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.12 * glowVal),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.secondaryColor.withOpacity(0.08 * glowVal),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor.withOpacity(0.04 * glowVal),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopPanel(bool isDark, bool isSmallDevice) {
    return FadeTransition(
      opacity: _entryFadeAnimation,
      child: SlideTransition(
        position: _entrySlideAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowVal = _glowController.value;
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallDevice ? 6 : 10,
                    vertical: isSmallDevice ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08 + 0.04 * glowVal),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(
                          0.06 * glowVal,
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildSpeedGauge(isDark, isSmallDevice),
                      SizedBox(width: isSmallDevice ? 4 : 8),
                      Container(
                        width: 1,
                        height: isSmallDevice ? 16 : 22,
                        color: Colors.white24,
                      ),
                      SizedBox(width: isSmallDevice ? 4 : 8),
                      _buildHeadingDisplay(isDark, isSmallDevice),
                      const Spacer(),
                      _buildStatusIcons(isDark),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedGauge(bool isDark, bool isSmallDevice) {
    return ValueListenableBuilder<double>(
      valueListenable: _flowController.speedNotifier,
      builder: (context, speed, _) {
        final speedKmH = speed * 3.6;
        final speedColor = _getSpeedColor(speedKmH);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 6 : 10,
            vertical: isSmallDevice ? 3 : 5,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                speedColor.withOpacity(0.25),
                speedColor.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: speedColor.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: speedColor.withOpacity(0.15),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(
                Icons.speed_rounded,
                color: speedColor.withOpacity(0.85),
                size: isSmallDevice ? 11 : 13,
              ),
              SizedBox(width: isSmallDevice ? 3 : 5),
              Text(
                speedKmH.toStringAsFixed(0),
                style: TextStyle(
                  color: speedColor,
                  fontSize: isSmallDevice ? 14 : 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(width: isSmallDevice ? 1 : 2),
              Text(
                'km/h',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: isSmallDevice ? 7 : 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeadingDisplay(bool isDark, bool isSmallDevice) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 6 : 10,
        vertical: isSmallDevice ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.25),
            AppTheme.primaryColor.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: isSmallDevice ? 11 : 13,
            height: isSmallDevice ? 11 : 13,
            child: CustomPaint(
              painter: _MiniCompassPainter(
                color: AppTheme.primaryColor.withOpacity(0.85),
              ),
            ),
          ),
          SizedBox(width: isSmallDevice ? 3 : 5),
          ValueListenableBuilder<double>(
            valueListenable: _flowController.headingNotifier,
            builder: (context, heading, _) {
              return Text(
                '${heading.toStringAsFixed(0)}° ${_getCardinalDirection(heading)}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: isSmallDevice ? 12 : 16,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcons(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_flowController.hasValidGps)
          _buildStatusChip(
            Icons.gps_fixed_rounded,
            AppTheme.successColor,
            _getGpsAccuracyLabel(_flowController.currentGpsAccuracy),
          ),
        if (_flowController.isModelLoaded)
          _buildStatusChip(
            Icons.visibility_rounded,
            AppTheme.primaryColor,
            'AI',
          ),
      ],
    );
  }

  Widget _buildStatusChip(IconData icon, Color color, String label) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.3), color.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15 * pulseVal),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 10),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTurnInstruction(bool isSmallDevice) {
    return Consumer<NavigationController>(
      builder: (context, navController, _) {
        if (!navController.isNavigating || navController.currentStep == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 46,
          left: 6,
          right: 6,
          child: TurnInstructionCard(
            currentStep: navController.currentStep,
            destinationName: navController.currentRoute?.destinationName ?? '',
            progressPercentage: navController.progressPercentage,
          ),
        );
      },
    );
  }

  Widget _buildMiniControls(bool isDark, bool isSmallDevice) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 4 : 6,
            vertical: isSmallDevice ? 2 : 3,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMiniButton(
                icon: _flowController.isPlaying && !_flowController.isPaused
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: () {
                  if (!_flowController.isPlaying) {
                    _flowController.pickAndPlayVideo();
                  } else {
                    _flowController.togglePause();
                  }
                  setState(() {});
                },
              ),
              SizedBox(width: isSmallDevice ? 2 : 4),
              _buildMiniButton(
                icon: Icons.folder_open_rounded,
                onTap: () {
                  _flowController.pickAndPlayVideo();
                  setState(() {});
                },
              ),
              if (_flowController.isPlaying) ...[
                SizedBox(width: isSmallDevice ? 2 : 4),
                _buildMiniButton(
                  icon: _flowController.isPaused
                      ? Icons.speed_rounded
                      : Icons.skip_next_rounded,
                  onTap: () {
                    _flowController.cycleSpeed();
                    setState(() {});
                  },
                  badge: _flowController.playbackSpeed != 1.0
                      ? '${_flowController.playbackSpeed}x'
                      : null,
                ),
              ],
              if (_isDebugMode) ...[
                SizedBox(width: isSmallDevice ? 2 : 4),
                _buildMiniButton(
                  icon: Icons.grid_on_rounded,
                  isActive: true,
                  activeColor: AppTheme.secondaryColor,
                  onTap: () {
                    setState(() {
                      _isDebugMode = false;
                    });
                  },
                ),
              ] else ...[
                SizedBox(width: isSmallDevice ? 2 : 4),
                _buildMiniButton(
                  icon: Icons.grid_3x3_rounded,
                  onTap: () {
                    setState(() {
                      _isDebugMode = true;
                    });
                  },
                ),
              ],
              SizedBox(width: isSmallDevice ? 2 : 4),
              _buildMiniButton(
                icon: _flowController.voiceEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                isActive: _flowController.voiceEnabled,
                activeColor: AppTheme.successColor,
                onTap: () {
                  _flowController.toggleVoice();
                  setState(() {});
                },
              ),
              if (_flowController.aiObstacles.isNotEmpty) ...[
                SizedBox(width: isSmallDevice ? 2 : 4),
                _buildObstacleIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? AppTheme.primaryColor)
        : Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (activeColor ?? AppTheme.primaryColor).withOpacity(0.2),
                      (activeColor ?? AppTheme.primaryColor).withOpacity(0.05),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
            border: Border.all(
              color: isActive
                  ? (activeColor ?? AppTheme.primaryColor).withOpacity(0.4)
                  : Colors.white.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? (activeColor ?? AppTheme.primaryColor).withOpacity(0.15)
                    : Colors.black.withOpacity(0.2),
                blurRadius: isActive ? 6 : 4,
                offset: isActive ? Offset.zero : const Offset(0, 2),
              ),
            ],
          ),
          child: badge != null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: effectiveColor, size: 14),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(icon, color: effectiveColor, size: 14),
        ),
      ),
    );
  }

  Widget _buildObstacleIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor.withOpacity(0.35),
                AppTheme.accentColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.accentColor.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(
                  0.15 + 0.1 * (pulseVal - 1.0) / 0.08,
                ),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.accentColor,
                size: 11,
              ),
              const SizedBox(width: 2),
              Text(
                '${_flowController.aiObstacles.length}',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapSection(bool isDark, bool isSmallDevice) {
    return Consumer<NavigationController>(
      builder: (context, navController, _) {
        if (!navController.isNavigating || navController.currentRoute == null) {
          return _buildNoRoutePanel(isDark, isSmallDevice);
        }

        return Column(
          children: [
            _buildNavigationInfoBar(navController, isDark, isSmallDevice),
            Expanded(
              child: NavigationMapWidget(
                headingNotifier: _flowController.headingNotifier,
                route: navController.currentRoute,
                onExitNavigation: () {
                  navController.stopNavigation();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationInfoBar(
    NavigationController navController,
    bool isDark,
    bool isSmallDevice,
  ) {
    final route = navController.currentRoute;
    if (route == null) return const SizedBox.shrink();

    final currentStep = navController.currentStep;
    final progress = navController.progressPercentage;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 8 : 12,
        vertical: isSmallDevice ? 5 : 7,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF12162E), const Color(0xFF0D1025)]
              : [AppTheme.cardLight, AppTheme.surfaceLight],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.secondaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallDevice ? 4 : 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.secondaryColor.withOpacity(0.3),
                      AppTheme.secondaryColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withOpacity(0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.navigation_rounded,
                  color: AppTheme.secondaryColor,
                  size: isSmallDevice ? 12 : 16,
                ),
              ),
              SizedBox(width: isSmallDevice ? 6 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentStep?.name != null &&
                        currentStep!.name!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          currentStep.name!,
                          style: TextStyle(
                            color: AppTheme.secondaryColor.withOpacity(0.8),
                            fontSize: isSmallDevice ? 8 : 9,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      route.destinationName.isNotEmpty
                          ? route.destinationName
                          : 'Điểm đến',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textDark,
                        fontSize: isSmallDevice ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallDevice ? 1 : 2),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.straighten_rounded,
                          route.distanceText,
                          AppTheme.successColor,
                          isSmallDevice,
                        ),
                        SizedBox(width: isSmallDevice ? 4 : 8),
                        _buildInfoChip(
                          Icons.timer_rounded,
                          route.durationText,
                          AppTheme.secondaryColor,
                          isSmallDevice,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCloseButton(navController, isDark, isSmallDevice),
            ],
          ),
          if (progress > 0) ...[
            SizedBox(height: isSmallDevice ? 3 : 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.secondaryColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text,
    Color color,
    bool isSmallDevice,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmallDevice ? 9 : 11),
        SizedBox(width: isSmallDevice ? 2 : 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: isSmallDevice ? 8 : 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton(
    NavigationController navController,
    bool isDark,
    bool isSmallDevice,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          navController.stopNavigation();
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isSmallDevice ? 4 : 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentColor.withOpacity(0.2),
                AppTheme.accentColor.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.accentColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            color: AppTheme.accentColor.withOpacity(0.9),
            size: isSmallDevice ? 12 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildNoRoutePanel(bool isDark, bool isSmallDevice) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0D1025), const Color(0xFF060A18)]
              : [AppTheme.surfaceLight, AppTheme.backgroundLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowVal = _glowController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -10,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.secondaryColor.withOpacity(
                                0.08 * glowVal,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      left: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.06 * glowVal),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 30,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.accentColor.withOpacity(0.04 * glowVal),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: isSmallDevice ? 54 : 68,
                        height: isSmallDevice ? 54 : 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.secondaryColor.withOpacity(0.22),
                              AppTheme.primaryColor.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: AppTheme.secondaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryColor.withOpacity(0.12),
                              blurRadius: 16,
                            ),
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.06),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: AppTheme.secondaryColor.withOpacity(0.85),
                          size: isSmallDevice ? 24 : 28,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isSmallDevice ? 8 : 12),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: Text(
                    'Chưa có tuyến đường',
                    style: TextStyle(
                      fontSize: isSmallDevice ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                SizedBox(height: isSmallDevice ? 3 : 5),
                Text(
                  'Vui lòng chọn điểm đến trên bản đồ',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: isSmallDevice ? 9 : 11,
                  ),
                ),
                SizedBox(height: isSmallDevice ? 4 : 6),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return Opacity(
                      opacity:
                          0.4 + 0.15 * (_pulseAnimation.value - 1.0) / 0.08,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Quay lại bản đồ để thiết lập lộ trình',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: isSmallDevice ? 8 : 9,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: isSmallDevice ? 10 : 16),
                _buildReturnButton(isDark, isSmallDevice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnButton(bool isDark, bool isSmallDevice) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 14 : 20,
            vertical: isSmallDevice ? 6 : 9,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.28),
                AppTheme.secondaryColor.withOpacity(0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.primaryColor.withOpacity(0.85),
                size: isSmallDevice ? 13 : 15,
              ),
              SizedBox(width: isSmallDevice ? 5 : 7),
              Text(
                'Quay lại bản đồ',
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : AppTheme.textDark.withOpacity(0.75),
                  fontSize: isSmallDevice ? 10 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectVideoButton(bool isDark) {
    return GestureDetector(
      onTap: _flowController.pickAndPlayVideo,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + (_shimmerController.value * 2), 0),
                end: Alignment(1, 0),
                colors: const [
                  AppTheme.primaryColor,
                  AppTheme.secondaryColor,
                  AppTheme.primaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'BẮT ĐẦU PHÂN TÍCH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getCardinalDirection(double heading) {
    const directions = ['B', 'ĐB', 'Đ', 'ĐN', 'N', 'TN', 'T', 'TB'];
    int index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  Color _getSpeedColor(double speedKmH) {
    if (speedKmH > 80) return AppTheme.accentColor;
    if (speedKmH > 40) return AppTheme.warningColor;
    return AppTheme.secondaryColor;
  }

  String _getGpsAccuracyLabel(double accuracy) {
    if (accuracy <= 0) return 'GPS';
    if (accuracy < 10) return 'GPS';
    if (accuracy < 25) return 'GPS~';
    return 'GPS';
  }
}

class _MiniCompassPainter extends CustomPainter {
  final Color color;

  _MiniCompassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.75, paint);

    final nPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final nPath = Path();
    final topY = center.dy - radius * 0.75;
    nPath.moveTo(center.dx, topY - radius * 0.2);
    nPath.lineTo(center.dx - radius * 0.18, topY + radius * 0.15);
    nPath.lineTo(center.dx + radius * 0.18, topY + radius * 0.15);
    nPath.close();
    canvas.drawPath(nPath, nPaint);

    final bottomY = center.dy + radius * 0.75;
    canvas.drawLine(
      Offset(center.dx - radius * 0.12, bottomY),
      Offset(center.dx + radius * 0.12, bottomY),
      paint..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniCompassPainter oldDelegate) =>
      color != oldDelegate.color;
}
