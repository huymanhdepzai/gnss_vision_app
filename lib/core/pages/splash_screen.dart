import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/map/presentation/pages/map_home_page.dart';
import '../app_theme.dart';
import '../utils/injection_container.dart';
import '../widgets/gnss_vision_icon.dart';
import 'onboarding_screen.dart';

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

  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initAnimations();
    _startInitialization();
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
  }

  Future<void> _startInitialization() async {
    if (_isInitializing) return;
    _isInitializing = true;

    // 1. Khởi tạo animations
    if (mounted) _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _textController.forward();

    // 2. Yêu cầu quyền truy cập TRƯỚC
    await _handlePermissions();

    if (!mounted) return;

    // 3. Chờ GetIt sẵn sàng
    try {
      debugPrint('Waiting for GetIt services to be ready...');
      await sl.allReady(timeout: const Duration(seconds: 15));
      debugPrint('GetIt services ready.');
    } catch (e) {
      debugPrint('Error or Timeout waiting for services: $e');
    }
    
    if (!mounted) return;

    // 4. Đợi AuthBloc xác định trạng thái
    await _waitForAuth();

    if (!mounted) return;

    // 5. Chờ ít nhất 1 giây để người dùng thấy logo (nếu nhanh quá)
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _navigateToHome();
  }

  Future<void> _waitForAuth() async {
    // Nếu AuthBloc đang ở trạng thái initial hoặc loading, chờ nó hoàn thành
    final authBloc = context.read<AuthBloc>();
    
    bool isDetermined(AuthState state) => state.maybeWhen(
      authenticated: (user, isBio) => true,
      unauthenticated: (isBio) => true,
      error: (_) => true,
      orElse: () => false,
    );

    if (!isDetermined(authBloc.state)) {
      await authBloc.stream.firstWhere((state) => isDetermined(state));
    }
  }

  Future<void> _handlePermissions() async {
    try {
      final permissions = [
        Permission.camera,
        Permission.locationWhenInUse,
        Permission.microphone,
        Permission.notification,
      ];

      Map<Permission, PermissionStatus> statuses = await permissions.request();
      
      statuses.forEach((permission, status) {
        debugPrint('Permission $permission result: $status');
      });

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;

    // 1. Kiểm tra trạng thái onboarding
    final bool onboardingComplete = await OnboardingScreen.hasCompletedOnboarding();
    if (!mounted) return;

    if (!onboardingComplete) {
      _pushScreen(const OnboardingScreen());
      return;
    }

    // 2. Kiểm tra trạng thái đăng nhập
    final authState = context.read<AuthBloc>().state;
    authState.maybeWhen(
      authenticated: (user, isBio) => _pushScreen(const MapHomeScreenV2()),
      unauthenticated: (isBio) => _pushScreen(const LoginPage()),
      error: (_) => _pushScreen(const LoginPage()),
      orElse: () => _pushScreen(const LoginPage()),
    );
  }

  void _pushScreen(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: Stack(
        children: [
          ..._buildAmbientGlows(isDark),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: _buildLogo(isDark),
                    );
                  },
                ),
                // const SizedBox(height: 48),
                // SlideTransition(
                //   position: _textSlideAnimation,
                //   child: FadeTransition(
                //     opacity: _textFadeAnimation,
                //     child: _buildTitle(isDark),
                //   ),
                // ),
                const SizedBox(height: 80),
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: _buildLoadingIndicator(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background glow behind the icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2 * _pulseController.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              const AnimatedGnssVisionIcon(
                size: 110,
                showGlow: false,
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildLoadingIndicator(bool isDark) {
    return SizedBox(
      width: 160,
      child: AnimatedBuilder(
        animation: _logoController,
        builder: (context, child) {
          return Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: _logoController.value,
                  backgroundColor: (isDark ? Colors.white : AppTheme.primaryColor).withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.secondaryColor,
                  ),
                  minHeight: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Đang tải",
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: (isDark ? Colors.white : AppTheme.textDark).withOpacity(0.3),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildAmbientGlows(bool isDark) {
    return [
      // Top Left Soft Glow
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(isDark ? 0.08 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // Bottom Right Soft Glow
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withOpacity(isDark ? 0.06 : 0.03),
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

  // ParticleBackgroundPainter removed for a cleaner look.
