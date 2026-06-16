import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../controllers/camera_flow_controller.dart';
import '../widgets/flow_painter.dart';
import '../widgets/navigation_map_widget.dart';
import '../widgets/turn_instruction_card.dart';
import '../../../map/presentation/controllers/navigation_controller.dart';
import '../../../map/domain/entities/navigation_step.dart';

class NavigationVisionPage extends StatefulWidget {
  const NavigationVisionPage({super.key});

  @override
  State<NavigationVisionPage> createState() => _NavigationVisionPageState();
}

class _NavigationVisionPageState extends State<NavigationVisionPage>
    with TickerProviderStateMixin {
  final CameraFlowController _flowController = CameraFlowController();
  bool _isDebugMode = false;
  bool _isPiPExpanded = false;
  bool _isHeadingUp = false;

  final ValueNotifier<bool> _headingUpNotifier = ValueNotifier<bool>(false);

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _entryController;
  late AnimationController _shimmerController;
  late AnimationController _pipExpandController;

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

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pipExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 0.0,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _entrySlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _entryController.forward();
    _flowController.isDemoMode = false; // Tắt chế độ demo để dùng cảm biến thật
    _flowController.init().then((_) {
      // Tự động bật camera khi vào màn hình nếu model đã load
      _flowController.startCamera();
    });
    SystemChrome.setPreferredOrientations([]);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _entryController.dispose();
    _shimmerController.dispose();
    _pipExpandController.dispose();
    _flowController.dispose();
    _headingUpNotifier.dispose();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _togglePiPExpand() {
    setState(() => _isPiPExpanded = !_isPiPExpanded);
    if (_isPiPExpanded) {
      _pipExpandController.forward();
    } else {
      _pipExpandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 600;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF060A18) : AppTheme.backgroundLight,
          body: SafeArea(
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Consumer<NavigationController>(
                  builder: (context, navCtrl, _) {
                    return NavigationMapWidget(
                      headingNotifier: _flowController.headingNotifier,
                      headingUpNotifier: _headingUpNotifier,
                      route: navCtrl.currentRoute,
                      onExitNavigation: navCtrl.isNavigating
                          ? () {
                              navCtrl.stopNavigation();
                              Navigator.of(context).pop();
                            }
                          : null,
                    );
                  },
                ),
                Consumer<NavigationController>(
                  builder: (context, navCtrl, _) {
                    if (navCtrl.isNavigating && navCtrl.currentRoute != null) {
                      return const SizedBox.shrink();
                    }
                    return _buildNoRouteOverlay(isDark, isSmallDevice);
                  },
                ),
                Consumer<NavigationController>(
                  builder: (context, navCtrl, _) {
                    if (!navCtrl.isNavigating || navCtrl.currentRoute == null) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 8,
                      left: 10,
                      right: 10,
                      child: FadeTransition(
                        opacity: _entryFadeAnimation,
                        child: SlideTransition(
                          position: _entrySlideAnimation,
                          child: _buildNavInfoBar(navCtrl, isDark, isSmallDevice),
                        ),
                      ),
                    );
                  },
                ),
                Consumer<NavigationController>(
                  builder: (context, navCtrl, _) {
                    if (navCtrl.isNavigating && navCtrl.currentStep != null) {
                      return Positioned(
                        top: isSmallDevice ? 72 : 82,
                        left: 10,
                        right: 10,
                        child: Opacity(
                          opacity: 0.92,
                          child: TurnInstructionCard(
                            currentStep: navCtrl.currentStep,
                            destinationName: navCtrl.currentRoute?.destinationName ?? '',
                            progressPercentage: navCtrl.progressPercentage,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Consumer<NavigationController>(
                  builder: (context, navCtrl, _) {
                    if (navCtrl.isNavigating && navCtrl.currentRoute != null) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: FadeTransition(
                        opacity: _entryFadeAnimation,
                        child: SlideTransition(
                          position: _entrySlideAnimation,
                          child: _buildTopPanel(isDark, isSmallDevice),
                        ),
                      ),
                    );
                  },
                ),
                _buildVisionPiP(isDark, isSmallDevice),
                if (_flowController.aiObstacles.isNotEmpty)
                  Positioned(
                    bottom: isSmallDevice ? 60 : 66,
                    left: isSmallDevice ? 12 : 14,
                    child: FadeTransition(
                      opacity: _entryFadeAnimation,
                      child: _buildObstacleIndicator(),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: isSmallDevice ? 12 : 16,
                  child: FadeTransition(
                    opacity: _entryFadeAnimation,
                    child: _buildSideControlsColumn(isDark, isSmallDevice),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideControlsColumn(bool isDark, bool isSmallDevice) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeadingUpButton(isDark, isSmallDevice),
        const SizedBox(height: 12),
        _buildControlButton(
          icon: _flowController.isPlaying && !_flowController.isPaused
              ? Icons.videocam_off_rounded
              : Icons.videocam_rounded,
          onTap: () {
            if (!_flowController.isPlaying) {
              _flowController.startCamera();
            } else {
              _flowController.stopCamera();
            }
            setState(() {});
          },
          isActive: _flowController.isUsingCamera,
          activeColor: AppTheme.successColor,
          isSmallDevice: isSmallDevice,
        ),
        const SizedBox(height: 12),
        _buildControlButton(
          icon: _isDebugMode ? Icons.grid_on_rounded : Icons.grid_3x3_rounded,
          onTap: () => setState(() => _isDebugMode = !_isDebugMode),
          isActive: _isDebugMode,
          activeColor: AppTheme.secondaryColor,
          isSmallDevice: isSmallDevice,
        ),
        const SizedBox(height: 12),
        _buildControlButton(
          icon: _flowController.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          isActive: _flowController.voiceEnabled,
          activeColor: AppTheme.successColor,
          onTap: () {
            _flowController.toggleVoice();
            setState(() {});
          },
          isSmallDevice: isSmallDevice,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: _flowController.autoFocusEnabledNotifier,
          builder: (context, autoFocusEnabled, _) {
            return _buildControlButton(
              icon: autoFocusEnabled ? Icons.center_focus_strong_rounded : Icons.center_focus_weak_rounded,
              isActive: autoFocusEnabled,
              activeColor: AppTheme.primaryColor,
              onTap: () {
                _flowController.toggleAutoFocus();
              },
              isSmallDevice: isSmallDevice,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVisionPiP(bool isDark, bool isSmallDevice) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pipExpandController, _flowController]),
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_pipExpandController.value);
        final screenSize = MediaQuery.of(context).size;

        final collapsedW = isSmallDevice ? screenSize.width * 0.40 : screenSize.width * 0.36;
        final collapsedH = isSmallDevice ? screenSize.height * 0.22 : screenSize.height * 0.25;
        final expandedW = screenSize.width - 24;
        final expandedH = screenSize.height * 0.46;

        final width = lerpDouble(collapsedW, expandedW, t)!;
        final height = lerpDouble(collapsedH, expandedH, t)!;
        final radius = lerpDouble(16.0, 20.0, t)!;

        final bottomOffset = isSmallDevice ? 56.0 : 62.0;

        return Positioned(
          left: 12,
          bottom: bottomOffset,
          child: GestureDetector(
            onTap: _isPiPExpanded ? null : _togglePiPExpand,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18 + 0.12 * t),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: lerpDouble(14, 30, t)!,
                    offset: Offset(0, lerpDouble(4, 8, t)!),
                  ),
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.08 + 0.1 * t),
                    blurRadius: lerpDouble(10, 24, t)!,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPiPVideoContent(isDark),
                    _buildPiPOverlays(isDark, isSmallDevice, t, radius),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPiPVideoContent(bool isDark) {
    if (_flowController.isUsingCamera && _flowController.cameraController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapDown: (details) {
              _flowController.setTargetAt(details.localPosition);
            },
            child: CameraPreview(_flowController.cameraController!),
          ),
          ValueListenableBuilder<Rect?>(
            valueListenable: _flowController.targetBoxNotifier,
            builder: (context, targetBox, _) {
              return ValueListenableBuilder(
                valueListenable: _flowController.headingNotifier,
                builder: (context, heading, _) {
                  return CustomPaint(
                    painter: FlowPainter(
                      points: _flowController.pointsToDraw,
                      imageSize: _flowController.imageSize,
                      staticRois: _flowController.staticRois,
                      aiObstacles: _flowController.aiObstaclesNotifier.value,
                      isDebugMode: _isDebugMode,
                      confidence: null,
                      moveVector: null,
                      targetBox: targetBox,
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    }

    return ValueListenableBuilder(
      valueListenable: _flowController.frameNotifier,
      builder: (context, bytes, child) {
        if (bytes != null && _flowController.imageSize != Size.zero) {
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _flowController.imageSize.width,
              height: _flowController.imageSize.height,
              child: GestureDetector(
                onTapDown: (details) {
                  _flowController.setTargetAt(details.localPosition);
                },
                child: Stack(
                  children: [
                    Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
                    ValueListenableBuilder<Rect?>(
                      valueListenable: _flowController.targetBoxNotifier,
                      builder: (context, targetBox, _) {
                        return ValueListenableBuilder(
                          valueListenable: _flowController.headingNotifier,
                          builder: (context, heading, _) {
                            return CustomPaint(
                              painter: FlowPainter(
                                points: _flowController.pointsToDraw,
                                imageSize: _flowController.imageSize,
                                staticRois: _flowController.staticRois,
                                aiObstacles: _flowController.aiObstaclesNotifier.value,
                                isDebugMode: _isDebugMode,
                                confidence: null,
                                moveVector: null,
                                targetBox: targetBox,
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
          );
        }
        return _buildPiPPlaceholder(isDark);
      },
    );
  }

  Widget _buildPiPPlaceholder(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _glowController]),
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        final glowVal = _glowController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0A0E21), const Color(0xFF111833)]
                  : [const Color(0xFFF0F4FA), const Color(0xFFDEE5F0)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: pulseVal,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.25 * glowVal),
                          AppTheme.secondaryColor.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(isDark ? 0.35 : 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: isDark ? AppTheme.secondaryColor.withOpacity(0.9) : AppTheme.secondaryColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _flowController.startCamera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'BẬT CAMERA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPiPOverlays(bool isDark, bool isSmallDevice, double expandT, double radius) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_flowController.isPlaying)
          Positioned(
            top: 6,
            left: 6,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.4)]
                        : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withOpacity(0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: _buildPiPControlButton(
            icon: _isPiPExpanded ? Icons.compress_rounded : Icons.expand_rounded,
            onTap: _togglePiPExpand,
            isDark: isDark,
          ),
        ),
        if (_flowController.isPlaying && expandT < 0.5)
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: _buildPiPCollapsedInfo(isSmallDevice, isDark),
          ),
        if (expandT > 0.5 && _flowController.isPlaying)
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Opacity(
              opacity: ((expandT - 0.5) / 0.5).clamp(0.0, 1.0),
              child: _buildPiPExpandedInfo(isDark, isSmallDevice),
            ),
          ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<String?>(
            valueListenable: _flowController.relativeWarningNotifier,
            builder: (context, warning, _) {
              if (warning == null || warning.isEmpty) return const SizedBox.shrink();
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    warning,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPiPControlButton({required IconData icon, required VoidCallback onTap, required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.06)]
                    : [Colors.black.withOpacity(0.12), Colors.black.withOpacity(0.04)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.1), 
                  width: 1
                ),
              ),
              child: Icon(icon, color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87, size: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPiPCollapsedInfo(bool isSmallDevice, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                ? [Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.35)]
                : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _flowController.speedNotifier,
                builder: (context, speed, _) {
                  final speedKmH = (speed * 3.6).toStringAsFixed(0);
                  final color = _getSpeedColor(speed * 3.6);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_rounded, color: color, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        speedKmH,
                        style: TextStyle(
                          color: color,
                          fontSize: isSmallDevice ? 10 : 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        ' km/h',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: isSmallDevice ? 7 : 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_flowController.aiObstacles.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.accentColor, size: 11),
                    const SizedBox(width: 2),
                    Text(
                      '${_flowController.aiObstacles.length}',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: isSmallDevice ? 9 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPiPExpandedInfo(bool isDark, bool isSmallDevice) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.4)]
                : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.65)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), 
              width: 0.5
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _flowController.speedNotifier,
                builder: (context, speed, _) {
                  final speedKmH = speed * 3.6;
                  final color = _getSpeedColor(speedKmH);
                  return _buildPiPStatItem(
                    icon: Icons.speed_rounded,
                    value: speedKmH.toStringAsFixed(0),
                    unit: 'km/h',
                    color: color,
                    isSmallDevice: isSmallDevice,
                    isDark: isDark,
                  );
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: _flowController.headingNotifier,
                builder: (context, heading, _) {
                  return _buildPiPStatItem(
                    icon: Icons.explore_rounded,
                    value: heading.toStringAsFixed(0),
                    unit: '\u00b0 ${_getCardinalDirection(heading)}',
                    color: AppTheme.primaryColor,
                    isSmallDevice: isSmallDevice,
                    isDark: isDark,
                  );
                },
              ),
              if (_flowController.aiObstacles.isNotEmpty)
                _buildPiPStatItem(
                  icon: Icons.warning_amber_rounded,
                  value: '${_flowController.aiObstacles.length}',
                  unit: 'VT',
                  color: AppTheme.accentColor,
                  isSmallDevice: isSmallDevice,
                  isDark: isDark,
                ),
              if (_flowController.isModelLoaded)
                _buildPiPStatItem(
                  icon: Icons.visibility_rounded,
                  value: 'AI',
                  unit: '',
                  color: AppTheme.successColor,
                  isSmallDevice: isSmallDevice,
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPiPStatItem({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isSmallDevice,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmallDevice ? 13 : 15),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isSmallDevice ? 13 : 15,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: isSmallDevice ? 8 : 9,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildNoRouteOverlay(bool isDark, bool isSmallDevice) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowVal = _glowController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.65 + 0.05 * glowVal,
                  colors: isDark
                      ? [Colors.transparent, const Color(0xFF060A18).withOpacity(0.65 + 0.05 * glowVal)]
                      : [Colors.transparent, Colors.white.withOpacity(0.45 + 0.05 * glowVal)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavInfoBar(
    NavigationController navController,
    bool isDark,
    bool isSmallDevice,
  ) {
    final route = navController.currentRoute;
    if (route == null) return const SizedBox.shrink();

    final currentStep = navController.currentStep;
    final progress = navController.progressPercentage;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowVal = _glowController.value;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallDevice ? 10 : 14,
                vertical: isSmallDevice ? 7 : 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1A1F3D).withOpacity(0.88 + 0.04 * glowVal),
                          const Color(0xFF0D1025).withOpacity(0.85 + 0.04 * glowVal),
                        ]
                      : [
                          Colors.white.withOpacity(0.92 + 0.03 * glowVal),
                          const Color(0xFFF0F4FA).withOpacity(0.9 + 0.03 * glowVal),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.2 + 0.06 * glowVal),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.06 * glowVal),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallDevice ? 7 : 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryColor.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getManeuverIcon(currentStep?.maneuverType),
                          color: Colors.white,
                          size: isSmallDevice ? 18 : 24,
                        ),
                      ),
                      SizedBox(width: isSmallDevice ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              route.destinationName.isNotEmpty
                                  ? route.destinationName
                                  : '\u0110i\u1ec3m \u0111\u1ebfn',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppTheme.textDark,
                                fontSize: isSmallDevice ? 14 : 18,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildInfoChip(Icons.straighten_rounded, route.distanceText,
                                    AppTheme.successColor, isSmallDevice, isDark),
                                SizedBox(width: isSmallDevice ? 8 : 12),
                                _buildInfoChip(Icons.timer_rounded, route.durationText,
                                    AppTheme.secondaryColor, isSmallDevice, isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildCloseButton(navController, isDark, isSmallDevice),
                    ],
                  ),
                  if (progress > 0) ...[
                    SizedBox(height: isSmallDevice ? 8 : 10),
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryColor.withOpacity(0.35),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopPanel(bool isDark, bool isSmallDevice) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowVal = _glowController.value;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallDevice ? 8 : 12,
                vertical: isSmallDevice ? 4 : 6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.5 + 0.05 * glowVal),
                    Colors.black.withOpacity(0.35 + 0.04 * glowVal),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12 + 0.05 * glowVal),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.07 * glowVal),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildSpeedGauge(isDark, isSmallDevice),
                  SizedBox(width: isSmallDevice ? 5 : 9),
                  Container(
                    width: 1,
                    height: isSmallDevice ? 14 : 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white24, Colors.transparent],
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallDevice ? 5 : 9),
                  _buildHeadingDisplay(isDark, isSmallDevice),
                  const Spacer(),
                  _buildStatusIcons(isDark),
                ],
              ),
            );
          },
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
            horizontal: isSmallDevice ? 8 : 12,
            vertical: isSmallDevice ? 4 : 6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [speedColor.withOpacity(0.22), speedColor.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: speedColor.withOpacity(0.35), width: 1),
            boxShadow: [BoxShadow(color: speedColor.withOpacity(0.12), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(Icons.speed_rounded, color: speedColor.withOpacity(0.9), size: isSmallDevice ? 12 : 14),
              SizedBox(width: isSmallDevice ? 3 : 5),
              Text(
                speedKmH.toStringAsFixed(0),
                style: TextStyle(
                  color: speedColor,
                  fontSize: isSmallDevice ? 16 : 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(width: isSmallDevice ? 2 : 3),
              Text(
                'km/h',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: isSmallDevice ? 8 : 10,
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
        horizontal: isSmallDevice ? 8 : 12,
        vertical: isSmallDevice ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor.withOpacity(0.18), AppTheme.primaryColor.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: isSmallDevice ? 11 : 13,
            height: isSmallDevice ? 11 : 13,
            child: CustomPaint(painter: _MiniCompassPainter(color: AppTheme.primaryColor.withOpacity(0.9)))),
          SizedBox(width: isSmallDevice ? 4 : 6),
          ValueListenableBuilder<double>(
            valueListenable: _flowController.headingNotifier,
            builder: (context, heading, _) {
              return Text(
                '${heading.toStringAsFixed(0)}\u00b0 ${_getCardinalDirection(heading)}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: isSmallDevice ? 13 : 16,
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
          _buildStatusChip(Icons.gps_fixed_rounded, AppTheme.successColor, 'GPS'),
        if (_flowController.isModelLoaded)
          _buildStatusChip(Icons.visibility_rounded, AppTheme.primaryColor, 'AI'),
        if (_flowController.isPlaying)
          _buildStatusChip(Icons.fiber_manual_record_rounded, AppTheme.accentColor, 'LIVE'),
      ],
    );
  }

  Widget _buildStatusChip(IconData icon, Color color, String label) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.22), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.45), width: 1),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 5)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 10),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildObstacleIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor.withOpacity(0.3 + 0.1 * (pulseVal - 1.0) / 0.06),
                    AppTheme.accentColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withOpacity(0.55), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withOpacity(0.15 + 0.08 * (pulseVal - 1.0) / 0.06),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.accentColor, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${_flowController.aiObstacles.length} ch\u01b0\u1edbng ng\u1ea1i',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeadingUpButton(bool isDark, bool isSmallDevice) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        return GestureDetector(
          onTap: () {
            setState(() => _isHeadingUp = !_isHeadingUp);
            _headingUpNotifier.value = _isHeadingUp;
            HapticFeedback.mediumImpact();
          },
          child: Container(
            width: isSmallDevice ? 40 : 46,
            height: isSmallDevice ? 40 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isHeadingUp
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.secondaryColor.withOpacity(0.35 * pulseVal),
                        AppTheme.primaryColor.withOpacity(0.25 * pulseVal),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
              border: Border.all(
                color: _isHeadingUp
                    ? AppTheme.secondaryColor.withOpacity(0.7)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: _isHeadingUp
                  ? [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  color: _isHeadingUp
                      ? AppTheme.secondaryColor
                      : Colors.white.withOpacity(0.7),
                  size: isSmallDevice ? 18 : 22,
                ),
                if (_isHeadingUp)
                  Positioned(
                    bottom: isSmallDevice ? 5 : 6,
                    right: isSmallDevice ? 5 : 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
    bool isActive = false,
    Color? activeColor,
    required bool isSmallDevice,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? AppTheme.primaryColor)
        : Colors.white70;

    final double btnSize = isSmallDevice ? 40 : 46;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(btnSize / 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(btnSize / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [(activeColor ?? AppTheme.primaryColor).withOpacity(0.35), (activeColor ?? AppTheme.primaryColor).withOpacity(0.1)],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.3)],
                      ),
                border: Border.all(
                  color: isActive
                      ? (activeColor ?? AppTheme.primaryColor).withOpacity(0.6)
                      : Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: badge != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(icon, color: effectiveColor, size: isSmallDevice ? 18 : 22),
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Colors.black, fontSize: 6, fontWeight: FontWeight.w800, height: 1),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(icon, color: effectiveColor, size: isSmallDevice ? 18 : 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color, bool isSmallDevice, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isSmallDevice ? 11 : 13),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: isSmallDevice ? 10 : 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildCloseButton(NavigationController navController, bool isDark, bool isSmallDevice) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          navController.stopNavigation();
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accentColor.withOpacity(0.28), width: 1),
          ),
          child: Icon(Icons.close_rounded, color: AppTheme.accentColor, size: isSmallDevice ? 16 : 20),
        ),
      ),
    );
  }

  IconData _getManeuverIcon(ManeuverType? type) {
    if (type == null) return Icons.navigation_rounded;
    switch (type) {
      case ManeuverType.depart: return Icons.navigation_rounded;
      case ManeuverType.arrive: return Icons.flag_rounded;
      case ManeuverType.turn: return Icons.turn_right_rounded;
      case ManeuverType.fork: return Icons.fork_right_rounded;
      case ManeuverType.roundabout: return Icons.roundabout_right_rounded;
      case ManeuverType.merge: return Icons.merge_type_rounded;
      case ManeuverType.onRamp: return Icons.drive_eta_rounded;
      case ManeuverType.offRamp: return Icons.exit_to_app_rounded;
      case ManeuverType.ferry: return Icons.directions_boat_rounded;
      case ManeuverType.continueStraight: return Icons.straight_rounded;
      case ManeuverType.endOfRoad: return Icons.stop_rounded;
      case ManeuverType.newName: return Icons.straight_rounded;
      case ManeuverType.notification: return Icons.info_rounded;
    }
  }

  String _getCardinalDirection(double heading) {
    const directions = ['B', '\u0110B', '\u0110', '\u0110N', 'N', 'TN', 'T', 'TB'];
    int index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  Color _getSpeedColor(double speedKmH) {
    if (speedKmH > 80) return AppTheme.accentColor;
    if (speedKmH > 40) return AppTheme.warningColor;
    return AppTheme.secondaryColor;
  }

  
}

class _MiniCompassPainter extends CustomPainter {
  final Color color;
  _MiniCompassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final paint = Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.75, paint);
    final nPaint = Paint()..color = color..style = PaintingStyle.fill;
    final nPath = Path();
    final topY = center.dy - radius * 0.75;
    nPath.moveTo(center.dx, topY - radius * 0.2);
    nPath.lineTo(center.dx - radius * 0.18, topY + radius * 0.15);
    nPath.lineTo(center.dx + radius * 0.18, topY + radius * 0.15);
    nPath.close();
    canvas.drawPath(nPath, nPaint);
    final bottomY = center.dy + radius * 0.75;
    canvas.drawLine(Offset(center.dx - radius * 0.12, bottomY), Offset(center.dx + radius * 0.12, bottomY), paint..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant _MiniCompassPainter oldDelegate) => color != oldDelegate.color;
}