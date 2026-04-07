import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'map_home_screen_v2.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _navigateToHome();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
  }

  void _navigateToHome() {
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MapHomeScreenV2(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.1, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticleBackgroundPainter(_particleController.value),
                size: Size.infinite,
              );
            },
          ),
          ..._buildAmbientGlows(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Transform.rotate(
                        angle: _logoRotationAnimation.value,
                        child: _buildLogo(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: _buildTitle(),
                  ),
                ),
                const SizedBox(height: 60),
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: _buildLoadingIndicator(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(
                  0.5 * _pulseController.value,
                ),
                blurRadius: 30 * _pulseController.value,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.explore_rounded,
                size: 60,
                color: Colors.white.withOpacity(0.9),
              ),
              ...List.generate(3, (index) {
                return Transform.rotate(
                  angle:
                      (index * (2 * pi / 3)) +
                      (_particleController.value * 2 * pi),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3 - (index * 0.1)),
                        width: 1,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            "NAVIGATION",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "GNSS + VISION FUSION",
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 4,
            color: Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _logoController.value,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.secondaryColor,
                ),
                minHeight: 2,
                borderRadius: BorderRadius.circular(2),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            "Loading...",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAmbientGlows() {
    return [
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(
                      0.2 * _pulseController.value,
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
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withOpacity(
                      0.15 * (1 - _pulseController.value),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

class ParticleBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Random random = Random(42);

  ParticleBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 80; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = random.nextDouble() * 1.5 + 0.5;

      double twinkle = sin(animationValue * 2 * pi + i * 0.3) * 0.4 + 0.6;
      double opacity = (random.nextDouble() * 0.3 + 0.1) * twinkle;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
      );
    }

    for (int i = 0; i < 15; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double pulse = sin(animationValue * 2 * pi + i) * 0.5 + 0.5;

      canvas.drawCircle(
        Offset(x, y),
        2 + pulse * 2,
        Paint()..color = AppTheme.secondaryColor.withOpacity(0.1 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
