import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../utils/injection_container.dart';
import '../widgets/gnss_vision_icon.dart';
import '../../features/map/presentation/pages/map_home_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();

  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_complete') ?? false;
    } catch (_) {
      return false;
    }
  }
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _blobCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _titleCtrl;
  late AnimationController _subtitleCtrl;
  late AnimationController _pageCtrl;
  late AnimationController _mockupCtrl;
  late AnimationController _takeoverCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _blobProgress;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _titleAnim;
  late Animation<double> _subtitleAnim;
  late Animation<double> _mockupScale;
  late Animation<double> _mockupSlideY;
  late Animation<double> _takeoverIconScale;
  late Animation<double> _takeoverIconOpacity;
  late Animation<double> _takeoverGlowExpand;
  late Animation<double> _takeoverRipple1;
  late Animation<double> _takeoverRipple2;
  late Animation<double> _takeoverRipple3;
  late Animation<double> _takeoverFill;
  late Animation<double> _takeoverTextOpacity;
  late Animation<double> _takeoverTextScale;
  late Animation<double> _takeoverFlash;

  int _currentPage = 0;
  static const int _totalPages = 3;
  bool _introPlaying = true;
  bool _isTakingOver = false;
  bool _isTransitioning = false;

  static const _pages = [
    _OnboardPage(
      icon: Icons.navigation_rounded,
      title: 'Định Vị Thông Minh',
      desc: 'GNSS + Vision AI kết hợp\ntạo hệ thống định vị thế hệ mới',
      color1: Color(0xFF7C6AFF),
      color2: Color(0xFF22D3EE),
    ),
    _OnboardPage(
      icon: Icons.visibility_rounded,
      title: 'Nhìn Thấu Mọi Trở Ngại',
      desc: 'AI Camera nhận diện đối tượng\ncảnh báo real-time trên đường',
      color1: Color(0xFF22D3EE),
      color2: Color(0xFF7C6AFF),
    ),
    _OnboardPage(
      icon: Icons.satellite_alt_rounded,
      title: 'Theo Dõi Vệ Tinh',
      desc: 'GNSS đa tần số theo dõi\nvệ tinh thời gian thực chính xác',
      color1: Color(0xFF10B981),
      color2: Color(0xFF22D3EE),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _setupAnimations();
    _playIntro();
  }

  void _setupAnimations() {
    _blobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _subtitleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _mockupCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _takeoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();

    _blobProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blobCtrl, curve: Curves.easeOutCubic),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoRotate = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );
    _titleAnim = CurvedAnimation(
        parent: _titleCtrl, curve: Curves.easeOutCubic);
    _subtitleAnim = CurvedAnimation(
        parent: _subtitleCtrl, curve: Curves.easeOutCubic);
    _mockupScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _mockupCtrl, curve: Curves.easeOutBack),
    );
    _mockupSlideY = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _mockupCtrl, curve: Curves.easeOutCubic),
    );
    _takeoverIconScale = Tween<double>(begin: 0.8, end: 2.5).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack)),
    );
    _takeoverIconOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.5, 0.7, curve: Curves.easeIn)),
    );
    _takeoverGlowExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic)),
    );
    _takeoverRipple1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.1, 0.55, curve: Curves.easeOutCubic)),
    );
    _takeoverRipple2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)),
    );
    _takeoverRipple3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic)),
    );
    _takeoverFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic)),
    );
    _takeoverTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.52, 0.72, curve: Curves.easeOutCubic)),
    );
    _takeoverTextScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.52, 0.72, curve: Curves.easeOutCubic)),
    );
    _takeoverFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _takeoverCtrl,
          curve: const Interval(0.82, 0.95, curve: Curves.easeIn)),
    );
  }

  Future<void> _playIntro() async {
    await _blobCtrl.forward();
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _titleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _subtitleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _introPlaying = false);
    _mockupCtrl.forward();
    _pageCtrl.forward();
  }

  void _nextPage() async {
    if (_introPlaying || _isTakingOver || _isTransitioning) return;
    setState(() => _isTransitioning = true);
    if (_currentPage < _totalPages - 1) {
      await _pageCtrl.reverse();
      await _mockupCtrl.reverse();
      setState(() => _currentPage++);
      _mockupCtrl.forward(from: 0);
      _pageCtrl.forward(from: 0);
    } else {
      _startTakeover();
    }
    setState(() => _isTransitioning = false);
  }

  void _goToPage(int i) async {
    if (_introPlaying || _isTakingOver || _isTransitioning || i == _currentPage) {
      return;
    }
    setState(() => _isTransitioning = true);
    await _pageCtrl.reverse();
    await _mockupCtrl.reverse();
    setState(() => _currentPage = i);
    _mockupCtrl.forward(from: 0);
    _pageCtrl.forward(from: 0);
    setState(() => _isTransitioning = false);
  }

  void _startTakeover() async {
    setState(() => _isTakingOver = true);
    
    // Đảm bảo các dịch vụ đã sẵn sàng trước khi vào trang chủ
    await sl.allReady();
    
    _saveOnboardingComplete();
    _takeoverCtrl.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _a, _b) => const MapHomeScreenV2(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, a, _c, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        );
      }
    });
  }

  Future<void> _saveOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _pageCtrl.dispose();
    _mockupCtrl.dispose();
    _takeoverCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: GestureDetector(
        onTap: _introPlaying ? null : _nextPage,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            _buildParticles(size),
            _buildMorphingBackground(),
            if (_introPlaying) ...[
              _buildGradientBlob(size),
              _buildIntroContent(size),
            ],
            if (!_introPlaying && !_isTakingOver) ...[
              _buildPhoneMockup(size),
              _buildPageText(size),
              _buildNavigation(size),
            ],
            if (_isTakingOver) _buildTakeover(size),
          ],
        ),
      ),
    );
  }

  // ── Particle background ──

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (context, _) => CustomPaint(
        painter: _ParticlePainter(_particleCtrl.value),
        size: size,
      ),
    );
  }

  // ── Morphing gradient bg per page ──

  Widget _buildMorphingBackground() {
    if (_introPlaying) return const SizedBox.shrink();
    final page = _pages[_currentPage];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            page.color1.withOpacity(0.12),
            page.color2.withOpacity(0.06),
            AppTheme.backgroundDark,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }

  // ── Gradient blob (intro) ──

  Widget _buildGradientBlob(Size size) {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) => CustomPaint(
        painter: _GradientBlobPainter(
          progress: _blobProgress.value,
          color1: AppTheme.primaryColor,
          color2: AppTheme.secondaryColor,
        ),
        size: size,
      ),
    );
  }

  // ── Intro logo + text ──

  Widget _buildIntroContent(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _logoCtrl,
            builder: (context, _) => Transform.scale(
              scale: _logoScale.value,
              child: Transform.rotate(
                angle: _logoRotate.value,
                child: _buildLogoIcon(),
              ),
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _titleCtrl,
            builder: (context, _) => Opacity(
              opacity: _titleAnim.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _titleAnim.value)),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'GNSS VISION',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _subtitleCtrl,
            builder: (context, _) => Opacity(
              opacity: _subtitleAnim.value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - _subtitleAnim.value)),
                child: Text(
                  'Hệ Thống Di Động Thế Hệ Mới',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 4,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoIcon() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const GnssVisionIcon(size: 90, showGlow: false),
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _particleCtrl,
              builder: (context, _) => Transform.rotate(
                angle: (i * 2 * pi / 3) + _particleCtrl.value * 2 * pi,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25 - i * 0.08),
                      width: 1,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Phone mockup ──

  Widget _buildPhoneMockup(Size size) {
    final page = _pages[_currentPage];
    return Positioned(
      top: size.height * 0.1,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _mockupCtrl,
        builder: (context, _) => Transform.translate(
          offset: Offset(0, _mockupSlideY.value),
          child: Transform.scale(
            scale: _mockupScale.value,
            child: Opacity(
              opacity: ((_mockupScale.value - 0.6) / 0.4).clamp(0.0, 1.0),
              child: _PhoneMockup(page: page),
            ),
          ),
        ),
      ),
    );
  }

  // ── Page text ──

  Widget _buildPageText(Size size) {
    final page = _pages[_currentPage];
    return Positioned(
      bottom: size.height * 0.22,
      left: 32,
      right: 32,
      child: AnimatedBuilder(
        animation: _pageCtrl,
        builder: (context, _) => Opacity(
          opacity: _pageCtrl.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - _pageCtrl.value)),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [page.color1, page.color2],
                  ).createShader(bounds),
                  child: Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  page.desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dots + Button ──

  Widget _buildNavigation(Size size) {
    final page = _pages[_currentPage];
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _pageCtrl,
        builder: (context, _) => Opacity(
          opacity: _pageCtrl.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _goToPage(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? _pages[i].color1 : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _nextPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [page.color1, page.color2],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: page.color1.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentPage == _totalPages - 1
                        ? 'BẮT ĐẦU'
                        : 'TIẾP TỤC',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Takeover animation ──

  Widget _buildTakeover(Size size) {
    final page = _pages[_currentPage];
    final maxDim = size.width > size.height ? size.width : size.height;
    return AnimatedBuilder(
      animation: _takeoverCtrl,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_takeoverFill.value > 0)
              Center(
                child: Container(
                  width: maxDim * 2.5 * _takeoverFill.value,
                  height: maxDim * 2.5 * _takeoverFill.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.color1.withOpacity(0.85),
                        page.color2.withOpacity(0.45),
                        page.color1.withOpacity(0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ...List.generate(3, (i) {
              final ripples = [_takeoverRipple1, _takeoverRipple2, _takeoverRipple3];
              final progress = ripples[i].value;
              if (progress <= 0) return const SizedBox.shrink();
              final ringSize = maxDim * 1.5 * progress;
              final opacity = (1.0 - progress).clamp(0.0, 0.5);
              return Center(
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(opacity),
                      width: 2.0 - progress * 1.2,
                    ),
                  ),
                ),
              );
            }),
            if (_takeoverGlowExpand.value > 0)
              Center(
                child: Container(
                  width: 240 * _takeoverGlowExpand.value,
                  height: 240 * _takeoverGlowExpand.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.color1.withOpacity(0.7 * _takeoverGlowExpand.value),
                        page.color2.withOpacity(0.25 * _takeoverGlowExpand.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            if (_takeoverIconOpacity.value > 0.01)
              Center(
                child: Transform.scale(
                  scale: _takeoverIconScale.value,
                  child: Opacity(
                    opacity: _takeoverIconOpacity.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [page.color1, page.color2],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: page.color1.withOpacity(0.7),
                            blurRadius: 40,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(page.icon, size: 42, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (_takeoverTextOpacity.value > 0.01)
              Center(
                child: Opacity(
                  opacity: _takeoverTextOpacity.value,
                  child: Transform.scale(
                    scale: _takeoverTextScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [page.color1, page.color2, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'GNSS VISION',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bắt đầu hành trình',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_takeoverFlash.value > 0.01)
              Container(color: Colors.white.withOpacity(_takeoverFlash.value)),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Phone Mockup
// ════════════════════════════════════════════════════════════════════════════

class _PhoneMockup extends StatelessWidget {
  final _OnboardPage page;
  const _PhoneMockup({required this.page});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.cardDark, AppTheme.surfaceDark],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 2),
          boxShadow: [
            BoxShadow(
              color: page.color1.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: -5,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 80,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildScreenContent(),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10, left: 80, right: 80),
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenContent() {
    if (page.icon == Icons.navigation_rounded) return _buildNavScreen();
    if (page.icon == Icons.visibility_rounded) return _buildVisionScreen();
    return _buildGnssScreen();
  }

  // ── Navigation mockup ──

  Widget _buildNavScreen() {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2340),
                page.color1.withOpacity(0.1),
              ],
            ),
          ),
          child: Stack(
            children: [
              ...List.generate(
                7,
                (i) => Positioned(
                  left: i * 32.0 + 10,
                  top: 0,
                  bottom: 0,
                  child: Container(
                      width: 1, color: Colors.white.withOpacity(0.04)),
                ),
              ),
              ...List.generate(
                5,
                (i) => Positioned(
                  left: 0,
                  right: 0,
                  top: i * 36.0 + 6,
                  child: Container(
                      height: 1, color: Colors.white.withOpacity(0.04)),
                ),
              ),
              Positioned(
                top: 25,
                left: 25,
                right: 35,
                bottom: 45,
                child: CustomPaint(
                    painter: _RoutePainter(page.color1)),
              ),
              Positioned(
                top: 25,
                left: 22,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: page.color1,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: page.color1.withOpacity(0.5), blurRadius: 8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 45,
                right: 32,
                child: Icon(Icons.location_on,
                    color: page.color2, size: 22),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: page.color1.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('2.4 km',
                      style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.navigation_rounded, color: page.color1, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chuyến đi đang diễn ra',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    Text('ETA: 15 phút',
                        style: TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Vision mockup ──

  Widget _buildVisionScreen() {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF0D1B2A),
          ),
          child: Stack(
            children: [
              ..._cornerBrackets(page.color2),
              Positioned(
                top: 40,
                left: 24,
                child: Container(
                  width: 70,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: page.color2, width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text('Xe máy',
                        style: TextStyle(
                            color: page.color2,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Positioned(
                top: 55,
                right: 40,
                child: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.successColor, width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text('76%',
                        style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber,
                          color: AppTheme.warningColor, size: 10),
                      const SizedBox(width: 3),
                      const Text('2 cảnh báo',
                          style:
                              TextStyle(color: AppTheme.warningColor, fontSize: 8)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 90,
                left: 8,
                right: 8,
                child: Container(
                    height: 1, color: page.color2.withOpacity(0.2)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(page.color2, '3', 'Đối tượng'),
              _statItem(AppTheme.successColor, '2', 'An toàn'),
              _statItem(AppTheme.warningColor, '1', 'Cảnh báo'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Voice mockup ──

  Widget _buildGnssScreen() {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _GnssOrbitPainter(
                  orbitProgress: 0.7,
                  color: page.color1,
                ),
                size: const Size(200, 180),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [page.color1, page.color2],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.color1.withOpacity(0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.explore_rounded,
                    size: 22, color: Colors.white),
              ),
              ...List.generate(4, (i) {
                final angle = i * pi / 2 + 0.3;
                final rx = 70.0;
                final ry = 45.0;
                return Positioned(
                  left: 100 + rx * cos(angle) - 8,
                  top: 90 + ry * sin(angle) - 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: page.color2.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: page.color2.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.gps_fixed,
                        size: 8, color: Colors.white),
                  ),
                );
              }),
              Positioned(
                bottom: 8,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: page.color1.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed,
                          color: page.color1, size: 10),
                      const SizedBox(width: 3),
                      const Text('12 vệ tinh',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.my_location_rounded,
                      color: page.color1, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Độ chính xác: ±1.2m',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text('Dual-frequency GNSS',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(page.color1, '12', 'Vệ tinh'),
                  _statItem(page.color2, '4', 'Tín hiệu'),
                  _statItem(AppTheme.successColor, '±1m', 'Chính xác'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(Color color, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  List<Widget> _cornerBrackets(Color color) {
    const len = 16.0;
    return [
      Positioned(
        top: 6,
        left: 6,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color, width: 2),
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 2),
              right: BorderSide(color: color, width: 2),
            ),
            borderRadius:
                const BorderRadius.only(topRight: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 6,
        left: 6,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: 2),
              left: BorderSide(color: color, width: 2),
            ),
            borderRadius:
                const BorderRadius.only(bottomLeft: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 6,
        right: 6,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: 2),
              right: BorderSide(color: color, width: 2),
            ),
            borderRadius:
                const BorderRadius.only(bottomRight: Radius.circular(4)),
          ),
        ),
      ),
    ];
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Custom Painters
// ════════════════════════════════════════════════════════════════════════════

class _GradientBlobPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;

  _GradientBlobPainter({
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        sqrt(size.width * size.width + size.height * size.height) / 2;
    final radius = maxRadius * progress;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color1.withOpacity(0.35),
          color2.withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    if (progress > 0.2) {
      final innerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color1.withOpacity(0.5),
            color2.withOpacity(0.2),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius * 0.5));
      canvas.drawCircle(center, radius * 0.5, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientBlobPainter old) =>
      progress != old.progress;
}

class _ParticlePainter extends CustomPainter {
  final double value;
  static final _random = Random(42);
  static final _stars = List.generate(
      50,
      (i) => _Star(
            x: _random.nextDouble(),
            y: _random.nextDouble(),
            r: _random.nextDouble() * 1.5 + 0.5,
            phase: i * 0.3,
          ));

  _ParticlePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      final twinkle = sin(value * 2 * pi + star.phase) * 0.4 + 0.6;
      final opacity = (0.1 + star.r * 0.15) * twinkle;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.r,
        Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

class _RoutePainter extends CustomPainter {
  final Color color;
  _RoutePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.3, 0, size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(
        size.width * 0.7, size.height * 0.8, size.width, size.height * 0.7);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Star {
  final double x, y, r, phase;
  const _Star(
      {required this.x, required this.y, required this.r, required this.phase});
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String desc;
  final Color color1;
  final Color color2;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color1,
    required this.color2,
  });
}

class _GnssOrbitPainter extends CustomPainter {
  final double orbitProgress;
  final Color color;

  _GnssOrbitPainter({required this.orbitProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final orbitPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 160, height: 100),
      orbitPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 70),
      orbitPaint,
    );

    final signalPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final sx = cx + 80 * cos(angle);
      final sy = cy + 50 * sin(angle);
      canvas.drawLine(
        Offset(sx, sy),
        Offset(cx, cy),
        signalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GnssOrbitPainter old) =>
      orbitProgress != old.orbitProgress;
}