import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point_connection.dart';

// ============================================================
// SATELLITE SCREEN V2 - MODERN 3D UI
// ============================================================
// Tính năng mới:
// - Glassmorphism & Neumorphism
// - Animated transitions (Hero, Fade, Scale, Slide)
// - Particle background với animation
// - Shimmer loading effect
// - Pulse animation cho user location
// - Gradient text & icons
// - 3D card hover effects
// - Ambient glow effects
// ============================================================

class SatelliteData {
  final int prn;
  final double elevation;
  final double azimuth;
  final double snr;
  final String system;
  final bool usedInFix;

  SatelliteData({
    required this.prn,
    required this.elevation,
    required this.azimuth,
    required this.snr,
    required this.system,
    required this.usedInFix,
  });
}

class UserLocationData {
  final double latitude;
  final double longitude;
  UserLocationData({required this.latitude, required this.longitude});
}

class SatelliteScreenV2 extends StatefulWidget {
  const SatelliteScreenV2({Key? key}) : super(key: key);

  @override
  _SatelliteScreenV2State createState() => _SatelliteScreenV2State();
}

class _SatelliteScreenV2State extends State<SatelliteScreenV2>
    with TickerProviderStateMixin {
  List<SatelliteData> _satellites = [];
  UserLocationData? _userLocation;

  StreamSubscription? _gnssSubscription;
  Timer? _mockTimer;

  bool _showGlobe = true;
  bool _isUsingRealData = false;
  bool _isGlobeLoaded = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _floatingController;
  late AnimationController _glowController;

  // Curved Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  static const EventChannel _gnssChannel = EventChannel('gnss_status_channel');

  late FlutterEarthGlobeController _globeController;
  final Set<String> _activePointIds = {};
  final Set<String> _activeConnectionIds = {};

  @override
  void initState() {
    super.initState();

    _initAnimationControllers();
    _initGlobeController();
    _initRealGnssData();
  }

  void _initAnimationControllers() {
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
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _initGlobeController() {
    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.02, // Giảm tốc độ tự động xoay để cảm giác mượt hơn khi dùng tay trượt
      isRotating: true,
      zoom: 0.5,
      surface: const AssetImage('assets/images/earth-night.jpg'),
    );

    _globeController.onLoaded = () {
      if (mounted) {
        setState(() => _isGlobeLoaded = true);
        _updateGlobePoints();
      }
    };

    // Fallback: Nếu sau 2 giây không thấy gọi onLoaded, tự động kích hoạt
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isGlobeLoaded) {
        setState(() => _isGlobeLoaded = true);
        _updateGlobePoints();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _floatingController.dispose();
    _glowController.dispose();
    _gnssSubscription?.cancel();
    _mockTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRealGnssData() async {
    var permission = await Permission.locationWhenInUse.request();

    if (permission.isGranted) {
      try {
        setState(() {
          _userLocation = UserLocationData(
            latitude: 21.028511,
            longitude: 105.804817,
          );
        });
        _updateGlobePoints();

        _gnssSubscription = _gnssChannel.receiveBroadcastStream().listen(
          (event) {
            if (!mounted) return;

            final List<dynamic> rawList = event as List<dynamic>;
            if (rawList.isEmpty && !_isUsingRealData) return;

            final random = Random();
            List<SatelliteData> realSats = [];

            for (var sat in rawList) {
              realSats.add(
                SatelliteData(
                  prn: sat['svid'] ?? 0,
                  elevation: (sat['elevationDegrees'] ?? 0.0).toDouble(),
                  azimuth: (sat['azimuthDegrees'] ?? 0.0).toDouble(),
                  snr: (sat['cn0DbHz'] ?? 0.0).toDouble(),
                  system: _getConstellationName(sat['constellationType'] ?? 0),
                  usedInFix: sat['usedInFix'] ?? false,
                ),
              );
            }

            setState(() {
              _satellites = realSats;
              _isUsingRealData = true;
            });
            _updateGlobePoints();

            _mockTimer?.cancel();
          },
          onError: (err) {
            _startMockDataFallback();
          },
        );

        _startMockDataFallback();
      } catch (e) {
        _startMockDataFallback();
      }
    } else {
      _startMockDataFallback();
    }
  }

  void _updateGlobePoints() {
    if (!_isGlobeLoaded) return;

    for (var id in _activePointIds) {
      _globeController.removePoint(id);
    }
    for (var id in _activeConnectionIds) {
      _globeController.removePointConnection(id);
    }
    _activePointIds.clear();
    _activeConnectionIds.clear();

    if (_userLocation != null) {
      const String userId = 'user_location';
      _globeController.addPoint(
        Point(
          id: userId,
          coordinates: GlobeCoordinates(
            _userLocation!.latitude,
            _userLocation!.longitude,
          ),
          label: 'Vị trí của bạn',
          isLabelVisible: true,
          style: const PointStyle(color: Colors.cyanAccent, size: 10),
        ),
      );
      _activePointIds.add(userId);
    }

    var topSats = _satellites.where((s) => s.usedInFix).toList();
    topSats.sort((a, b) => b.snr.compareTo(a.snr));
    var displaySats = topSats.take(8).toList();

    for (var sat in displaySats) {
      Color satColor = _getSatelliteColor(sat.system);

      double offsetLat =
          (90 - sat.elevation) * cos(sat.azimuth * pi / 180) * 0.15;
      double offsetLng =
          (90 - sat.elevation) * sin(sat.azimuth * pi / 180) * 0.15;

      GlobeCoordinates satCoords = GlobeCoordinates(
        (_userLocation?.latitude ?? 0) + offsetLat,
        (_userLocation?.longitude ?? 0) + offsetLng,
      );

      final String satId = 'sat_${sat.prn}';
      _globeController.addPoint(
        Point(
          id: satId,
          coordinates: satCoords,
          label: '${sat.system} ${sat.prn}',
          isLabelVisible: true,
          style: PointStyle(color: satColor, size: 6),
        ),
      );
      _activePointIds.add(satId);

      if (_userLocation != null) {
        final String connId = 'conn_${sat.prn}';
        _globeController.addPointConnection(
          PointConnection(
            id: connId,
            start: GlobeCoordinates(
              _userLocation!.latitude,
              _userLocation!.longitude,
            ),
            end: satCoords,
            isLabelVisible: false,
          ),
        );
        _activeConnectionIds.add(connId);
      }
    }
  }

  Color _getSatelliteColor(String system) {
    switch (system) {
      case "GPS":
        return const Color(0xFF00D4FF);
      case "GLONASS":
        return const Color(0xFFFF5252);
      case "GALILEO":
        return const Color(0xFFB388FF);
      case "BEIDOU":
        return const Color(0xFF69F0AE);
      case "QZSS":
        return const Color(0xFFFFAB40);
      default:
        return Colors.white;
    }
  }

  String _getConstellationName(int type) {
    switch (type) {
      case 1:
        return "GPS";
      case 2:
        return "SBAS";
      case 3:
        return "GLONASS";
      case 4:
        return "QZSS";
      case 5:
        return "BEIDOU";
      case 6:
        return "GALILEO";
      case 7:
        return "IRNSS";
      default:
        return "KHÔNG RÕ";
    }
  }

  void _startMockDataFallback() {
    if (_mockTimer != null && _mockTimer!.isActive) return;

    final random = Random();
    List<SatelliteData> sats = [];
    for (int i = 0; i < 12; i++) {
      String sys = i % 3 == 0 ? "GLONASS" : (i % 4 == 0 ? "GALILEO" : "GPS");
      sats.add(
        SatelliteData(
          prn: i + 10,
          elevation: random.nextDouble() * 80 + 10,
          azimuth: random.nextDouble() * 360,
          snr: random.nextDouble() * 25 + 20,
          system: sys,
          usedInFix: random.nextDouble() > 0.3,
        ),
      );
    }

    if (mounted) {
      setState(() => _satellites = sats);
      _updateGlobePoints();
    }

    _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isUsingRealData) return;
      setState(() {
        _satellites = _satellites.map((s) {
          return SatelliteData(
            prn: s.prn,
            elevation: (s.elevation + 0.1) % 90,
            azimuth: (s.azimuth + 0.2) % 360,
            snr: (s.snr + random.nextDouble() * 2 - 1).clamp(10.0, 50.0),
            system: s.system,
            usedInFix: s.usedInFix,
          );
        }).toList();
      });
      _updateGlobePoints();
    });
  }

  @override
  Widget build(BuildContext context) {
    int activeFixes = _satellites.where((s) => s.usedInFix).length;
    double avgSnr = _satellites.isNotEmpty
        ? _satellites.map((s) => s.snr).reduce((a, b) => a + b) /
              _satellites.length
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Ambient Glow Effects
          ..._buildAmbientGlows(),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildStatsOverview(activeFixes, avgSnr),
                Expanded(child: _buildMainView()),
                _buildBottomPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return CustomPaint(
          painter: AnimatedStarFieldPainter(_floatingController.value),
          size: Size.infinite,
        );
      },
    );
  }

  List<Widget> _buildAmbientGlows() {
    return [
      Positioned(
        top: -150,
        right: -100,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _glowController.value * 20),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.15 * _glowController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: 200,
        left: -50,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _glowController.value * -15),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purpleAccent.withOpacity(
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
      ),
    ];
  }

  Widget _buildAppBar() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: _buildGlassDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBackButton(),
              _buildTitleSection(),
              _buildStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF6C63FF)],
          ).createShader(bounds),
          child: const Text(
            "ĐỊNH VỊ VỆ TINH",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _isUsingRealData
                ? Colors.greenAccent.withOpacity(0.2)
                : Colors.orangeAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isUsingRealData
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  boxShadow: [
                    BoxShadow(
                      color: _isUsingRealData
                          ? Colors.greenAccent.withOpacity(0.5)
                          : Colors.orangeAccent.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isUsingRealData ? "GNSS TRỰC TIẾP" : "MÔ PHỎNG",
                style: TextStyle(
                  color: _isUsingRealData
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isUsingRealData
                  ? Colors.greenAccent.withOpacity(0.3)
                  : Colors.white24,
              width: 1,
            ),
            boxShadow: _isUsingRealData
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(
                        0.2 * _pulseAnimation.value,
                      ),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.settings_input_antenna_rounded,
            color: _isUsingRealData ? Colors.greenAccent : Colors.white24,
            size: 22,
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview(int activeFixes, double avgSnr) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: _buildGlassDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                "TRONG TẦM NHÌN",
                "${_satellites.length}",
                const Color(0xFF00D4FF),
                Icons.satellite_alt_rounded,
              ),
              _buildVerticalDivider(),
              _buildStatItem(
                "ĐANG SỬ DỤNG",
                "$activeFixes",
                const Color(0xFF69F0AE),
                Icons.my_location_rounded,
              ),
              _buildVerticalDivider(),
              _buildStatItem(
                "SNR TB",
                "${avgSnr.toStringAsFixed(1)}",
                const Color(0xFFFFAB40),
                Icons.signal_cellular_alt_rounded,
                suffix: "dB",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white24, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon, {
    String suffix = "",
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: double.parse(value.isEmpty ? "0" : value),
                ),
                duration: const Duration(milliseconds: 800),
                builder: (context, val, child) {
                  return Text(
                    val.toStringAsFixed(0),
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      shadows: [
                        Shadow(color: color.withOpacity(0.5), blurRadius: 10),
                      ],
                    ),
                  );
                },
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _showGlobe ? _buildGlobeView() : _buildRadarView(),
    );
  }

  Widget _buildGlobeView() {
    return Stack(
      key: const ValueKey('globe'),
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 320 * _pulseAnimation.value,
              height: 320 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
        Opacity(
          opacity: _isGlobeLoaded ? 1.0 : 0.0,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            child: FlutterEarthGlobe(
              controller: _globeController,
              radius: 140,
              // isInteractive: true, // Cho phép xoay và thu phóng bằng tay
            ),
          ),
        ),
        if (!_isGlobeLoaded)
          _buildLoadingIndicator(),

        if (_isGlobeLoaded) 
          _buildOrbitalRings(),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildOrbitalRings() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return CustomPaint(
              painter: OrbitalRingsPainter(_floatingController.value),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRadarView() {
    return Padding(
      key: const ValueKey('radar'),
      padding: const EdgeInsets.all(30.0),
      child: Container(
        decoration: _buildGlassDecoration(),
        padding: const EdgeInsets.all(20),
        child: CustomPaint(
          size: Size.infinite,
          painter: ModernRadarPainter(
            _satellites,
            _pulseController,
            _shimmerController,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.blueAccent.withOpacity(0.1),
                        Colors.blueAccent,
                        Colors.blueAccent.withOpacity(0.1),
                      ],
                      stops: [
                        0.0,
                        _shimmerController.value,
                        _shimmerController.value + 0.1,
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              "Đang tải địa cầu...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Positioned(
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              "ĐỊA CẦU 3D",
              Icons.public_rounded,
              _showGlobe,
              () => _switchView(true),
            ),
            _buildToggleButton(
              "SKYPLOT",
              Icons.radar_rounded,
              !_showGlobe,
              () => _switchView(false),
            ),
          ],
        ),
      ),
    );
  }

  void _switchView(bool showGlobe) {
    HapticFeedback.lightImpact();
    setState(() => _showGlobe = showGlobe);
  }

  Widget _buildToggleButton(
    String text,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF6C63FF)],
                )
              : null,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? Colors.white : Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 15),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF6C63FF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "DANH SÁCH VỆ TINH",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${_satellites.length}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  scrollDirection: Axis.horizontal,
                  itemCount: _satellites.length,
                  itemBuilder: (context, index) =>
                      _buildSatelliteCard(_satellites[index], index),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSatelliteCard(SatelliteData sat, int index) {
    Color color = _getSatelliteColor(sat.system);
    if (!sat.usedInFix) color = Colors.grey;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: Container(
              width: 110,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
                boxShadow: sat.usedInFix
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 15,
                          spreadRadius: -5,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCardHeader(sat, color),
                  _buildSignalBar(sat, color),
                  _buildCardFooter(sat, color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardHeader(SatelliteData sat, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "#${sat.prn}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            sat.usedInFix ? Icons.bolt_rounded : Icons.bolt_outlined,
            color: color,
            size: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalBar(SatelliteData sat, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            double fillHeight = ((sat.snr / 50) * 5 - i).clamp(0.0, 1.0);
            return Container(
              width: 6,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 6,
                    height: 30 * fillHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [color, color.withOpacity(0.5)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCardFooter(SatelliteData sat, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            sat.system,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${sat.snr.toInt()}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              " dB",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _buildGlassDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
    );
  }
}

// ============================================================
// CUSTOM PAINTERS
// ============================================================

class AnimatedStarFieldPainter extends CustomPainter {
  final double animationValue;

  AnimatedStarFieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    for (int i = 0; i < 150; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = random.nextDouble() * 1.5 + 0.5;

      double twinkle = sin(animationValue * pi * 2 + i * 0.5) * 0.3 + 0.7;
      double opacity = (random.nextDouble() * 0.4 + 0.2) * twinkle;

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    for (int i = 0; i < 20; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;

      double pulse = sin(animationValue * pi * 2 + i) * 0.5 + 0.5;

      final paint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(Offset(x, y), 3 + pulse * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedStarFieldPainter oldDelegate) => true;
}

class OrbitalRingsPainter extends CustomPainter {
  final double animationValue;

  OrbitalRingsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.25;

    for (int i = 0; i < 3; i++) {
      double radius = baseRadius + (i * 30);
      double rotation = animationValue * pi * 2 + (i * pi / 3);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);

      final paint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawCircle(center, radius, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant OrbitalRingsPainter oldDelegate) => true;
}

class ModernRadarPainter extends CustomPainter {
  final List<SatelliteData> satellites;
  final AnimationController pulseController;
  final AnimationController shimmerController;

  ModernRadarPainter(
    this.satellites,
    this.pulseController,
    this.shimmerController,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 20;

    _drawRadarBackground(canvas, center, maxRadius);
    _drawGridLines(canvas, center, maxRadius);
    _drawRadialLines(canvas, center, maxRadius);
    _drawSweepingLine(canvas, center, maxRadius);
    _drawSatellites(canvas, center, maxRadius);
    _drawCenterPulse(canvas, center);
  }

  void _drawRadarBackground(Canvas canvas, Offset center, double radius) {
    final gradient = RadialGradient(
      colors: [Colors.blueAccent.withOpacity(0.1), Colors.transparent],
      stops: const [0.0, 1.0],
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        ),
    );
  }

  void _drawGridLines(Canvas canvas, Offset center, double radius) {
    for (int i = 1; i <= 3; i++) {
      final paint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawCircle(center, radius * i / 3, paint);
    }
  }

  void _drawRadialLines(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 12; i++) {
      double angle = (i * 30) * pi / 180;
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..strokeWidth = 1;

      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        paint,
      );
    }
  }

  void _drawSweepingLine(Canvas canvas, Offset center, double radius) {
    double sweepAngle = (shimmerController.value * 360) * pi / 180;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withOpacity(0.3),
          Colors.cyanAccent.withOpacity(0.1),
        ],
        transform: GradientRotation(sweepAngle - pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - pi / 2 - 0.5,
      0.5,
      true,
      sweepPaint,
    );

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * cos(sweepAngle),
        center.dy + radius * sin(sweepAngle),
      ),
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.5)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawSatellites(Canvas canvas, Offset center, double radius) {
    for (var sat in satellites) {
      double r = radius * ((90 - sat.elevation) / 90);
      double theta = (sat.azimuth - 90) * pi / 180;
      double x = center.dx + r * cos(theta);
      double y = center.dy + r * sin(theta);

      Color color = _getSatelliteColor(sat.system);
      if (!sat.usedInFix) color = Colors.grey;

      if (sat.usedInFix) {
        canvas.drawCircle(
          Offset(x, y),
          15 + pulseController.value * 5,
          Paint()..color = color.withOpacity(0.1),
        );
      }

      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = color.withOpacity(0.3),
      );
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);

      final textPainter = TextPainter(
        text: TextSpan(
          text: "${sat.prn}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x + 10, y - 5));
    }
  }

  void _drawCenterPulse(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      10 + pulseController.value * 10,
      Paint()..color = Colors.cyanAccent.withOpacity(0.2),
    );
    canvas.drawCircle(center, 6, Paint()..color = Colors.cyanAccent);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  Color _getSatelliteColor(String system) {
    switch (system) {
      case "GPS":
        return const Color(0xFF00D4FF);
      case "GLONASS":
        return const Color(0xFFFF5252);
      case "GALILEO":
        return const Color(0xFFB388FF);
      case "BEIDOU":
        return const Color(0xFF69F0AE);
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant ModernRadarPainter oldDelegate) => true;
}
