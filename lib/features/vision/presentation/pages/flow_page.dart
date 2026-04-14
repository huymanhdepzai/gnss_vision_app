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
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  double _previousHeading = 0.0;
  double _turnIntensity = 0.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _controller.init();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
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
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0D1117),
                        const Color(0xFF161B22),
                        const Color(0xFF0D1117),
                      ]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFFFFFFF),
                        const Color(0xFFF1F5F9),
                      ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoBackground(isDark),
                _buildAmbientEffects(isDark),
                _buildTopPanel(topPadding, isDark),
                _buildNavigationHUD(isDark),
                _buildBottomPanel(bottomPadding, isDark),
                _buildObstacleWarnings(topPadding, isDark),
              ],
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
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                            return CustomPaint(
                              painter: FlowPainter(
                                points: _controller.pointsToDraw,
                                imageSize: _controller.imageSize,
                                staticRois: _controller.staticRois,
                                aiObstacles: _controller.aiObstacles,
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedLogo(isDark),
              const SizedBox(height: 40),
              _buildAppName(isDark),
              const SizedBox(height: 12),
              _buildTagline(isDark),
              const SizedBox(height: 48),
              _buildSelectVideoButton(isDark),
              const SizedBox(height: 24),
              // _buildFeatureCards(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo(bool isDark) {
    return AnimatedBuilder(
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
    );
  }

  Widget _buildAppName(bool isDark) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
      ).createShader(bounds),
      child: const Text(
        "VISION FLOW",
        style: TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
        ),
      ),
    );
  }

  Widget _buildTagline(bool isDark) {
    return Text(
      "Phân tích chuyển động thông minh",
      style: TextStyle(
        color: isDark ? Colors.white54 : Colors.black45,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildSelectVideoButton(bool isDark) {
    return GestureDetector(
      onTap: _controller.pickAndPlayVideo,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + (_shimmerController.value * 2), 0),
                end: Alignment(1, 0),
                colors: [
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
                const SizedBox(width: 12),
                const Text(
                  "BẮT ĐẦU PHÂN TÍCH",
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

  Widget _buildAmbientEffects(bool isDark) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(
                        0.15 * _glowController.value,
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
          animation: _pulseController,
          builder: (context, child) {
            return Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.secondaryColor.withOpacity(
                        0.12 * (1 - _pulseController.value),
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

  Widget _buildTopPanel(double topPadding, bool isDark) {
    final bgColors = isDark
        ? [
            const Color(0xFF1A1F2E).withOpacity(0.85),
            const Color(0xFF0F1420).withOpacity(0.75),
          ]
        : [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.88)];

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgColors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildSpeedGauge(isDark)),
                      Container(
                        width: 1,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      Expanded(flex: 2, child: _buildHeadingCompass(isDark)),
                      Container(
                        width: 1,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      Expanded(child: _buildStatusIndicators(isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedGauge(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final speed = _controller.isDemoMode
            ? 0.0
            : _controller.speedNotifier.value * 3.6;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "TỐC ĐỘ",
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _controller.isDemoMode ? "DEMO" : speed.toStringAsFixed(0),
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      shadows: [
                        Shadow(
                          color: AppTheme.secondaryColor.withOpacity(0.4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "km/h",
                    style: TextStyle(
                      color: AppTheme.secondaryColor.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeadingCompass(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.headingNotifier,
      builder: (context, heading, _) {
        final headingValue = heading.toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "HƯỚNG",
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "${headingValue.toStringAsFixed(0)}°",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      shadows: [
                        Shadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getDirectionString(headingValue),
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicators(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusDot(
                  isActive: _controller.hasValidGps,
                  color: AppTheme.successColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildStatusDot(
                  isActive: _controller.isModelLoaded,
                  color: AppTheme.secondaryColor,
                  isDark: isDark,
                  isLoading: !_controller.isModelLoaded,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _controller.isModelLoaded
                      ? [
                          AppTheme.successColor.withOpacity(0.2),
                          AppTheme.successColor.withOpacity(0.1),
                        ]
                      : [
                          AppTheme.warningColor.withOpacity(0.2),
                          AppTheme.warningColor.withOpacity(0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _controller.isModelLoaded
                      ? AppTheme.successColor.withOpacity(0.3)
                      : AppTheme.warningColor.withOpacity(0.3),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _controller.isModelLoaded
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      color: _controller.isModelLoaded
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _controller.isModelLoaded ? "ON" : "...",
                      style: TextStyle(
                        color: _controller.isModelLoaded
                            ? AppTheme.successColor.withOpacity(0.9)
                            : AppTheme.warningColor.withOpacity(0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusDot({
    required bool isActive,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? color.withOpacity(0.2)
                : (isDark ? Colors.white10 : Colors.black12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4 * _pulseController.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(
                  isActive ? Icons.check : Icons.close,
                  color: isActive
                      ? color
                      : (isDark ? Colors.white38 : Colors.black26),
                  size: 8,
                ),
        );
      },
    );
  }

  Widget _buildNavigationHUD(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.headingNotifier,
      builder: (context, heading, child) {
        if (_controller.frameNotifier.value == null)
          return const SizedBox.shrink();

        final currentHeading = heading.toDouble();
        if ((_previousHeading - currentHeading).abs() > 1.0) {
          _turnIntensity =
              (currentHeading - _previousHeading).clamp(-1.0, 1.0) * 0.5;
        }
        _previousHeading = currentHeading;

        return Positioned(
          bottom: 200,
          right: 20,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.95 + (_glowController.value * 0.05),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? [Colors.white.withOpacity(0.08), Colors.transparent]
                          : [
                              Colors.black.withOpacity(0.02),
                              Colors.transparent,
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: DirectionArrowPainter(
                      heading: currentHeading,
                      turnIntensity: _turnIntensity,
                      confidence: 0.8,
                      showPath: true,
                      primaryColor: AppTheme.primaryColor,
                      accentColor: AppTheme.secondaryColor,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildObstacleWarnings(double topPadding, bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _controller.frameNotifier,
      builder: (context, bytes, child) {
        if (bytes == null || _controller.aiObstacles.isEmpty)
          return const SizedBox.shrink();

        return Positioned(
          top: topPadding + 85,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = 0.7 + (_pulseController.value * 0.3);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.red.shade700.withOpacity(pulse),
                      Colors.red.shade500.withOpacity(pulse * 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.shade300.withOpacity(pulse),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "⚠ PHÁT HIỆN VẬT CẢN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${_controller.aiObstacles.length} vật thể phía trước",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_controller.aiObstacles.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(double bottomPadding, bool isDark) {
    return Positioned(
      bottom: bottomPadding + 20,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: _controller.progressNotifier,
              builder: (context, progress, child) =>
                  _buildProgressBar(progress, isDark),
            ),
            const SizedBox(height: 12),
            _buildControlsPanel(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool isDark) {
    final bgColors = isDark
        ? [
            const Color(0xFF1A1F2E).withOpacity(0.85),
            const Color(0xFF0F1420).withOpacity(0.75),
          ]
        : [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.88)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      color: AppTheme.primaryColor,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "${_controller.playbackSpeed}x",
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _controller.formatTime(
                  _controller.totalFrames,
                  _controller.fps,
                ),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: Colors.white,
              overlayColor: AppTheme.secondaryColor.withOpacity(0.2),
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
    final bgColors = isDark
        ? [
            const Color(0xFF1A1F2E).withOpacity(0.9),
            const Color(0xFF0F1420).withOpacity(0.8),
          ]
        : [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.9)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.folder_open_rounded,
                    onTap: _controller.pickAndPlayVideo,
                    isDark: isDark,
                  ),
                  _buildControlButton(
                    icon: _isDebugMode
                        ? Icons.grid_on_rounded
                        : Icons.grid_off_rounded,
                    color: _isDebugMode ? AppTheme.secondaryColor : null,
                    onTap: () => setState(() => _isDebugMode = !_isDebugMode),
                    isDark: isDark,
                  ),
                  _buildPlayButton(isDark),
                  _buildControlButton(
                    icon: _controller.voiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: _controller.voiceEnabled
                        ? AppTheme.successColor
                        : null,
                    onTap: _controller.toggleVoice,
                    isDark: isDark,
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color != null
              ? color.withOpacity(0.15)
              : (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(16),
          border: color != null
              ? Border.all(color: color.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Icon(
          icon,
          color: color ?? (isDark ? Colors.white70 : Colors.black54),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _controller.togglePause();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          _controller.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  String _getDirectionString(double heading) {
    if (heading >= 337.5 || heading < 22.5) return "B";
    if (heading >= 22.5 && heading < 67.5) return "ĐB";
    if (heading >= 67.5 && heading < 112.5) return "Đ";
    if (heading >= 112.5 && heading < 157.5) return "ĐN";
    if (heading >= 157.5 && heading < 202.5) return "N";
    if (heading >= 202.5 && heading < 247.5) return "TN";
    if (heading >= 247.5 && heading < 292.5) return "T";
    if (heading >= 292.5 && heading < 337.5) return "TB";
    return "";
  }
}
