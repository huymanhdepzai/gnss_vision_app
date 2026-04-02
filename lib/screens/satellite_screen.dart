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

// --- Models ---
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

class SatelliteScreen extends StatefulWidget {
  const SatelliteScreen({Key? key}) : super(key: key);

  @override
  _SatelliteScreenState createState() => _SatelliteScreenState();
}

class _SatelliteScreenState extends State<SatelliteScreen> {
  List<SatelliteData> _satellites = [];
  UserLocationData? _userLocation;

  StreamSubscription? _gnssSubscription;
  Timer? _mockTimer;

  bool _showGlobe = true;
  bool _isUsingRealData = false;

  // CỜ KIỂM SOÁT: Chỉ vẽ vệ tinh khi Trái đất 3D đã load xong
  bool _isGlobeLoaded = false;

  static const EventChannel _gnssChannel = EventChannel('gnss_status_channel');

  late FlutterEarthGlobeController _globeController;
  final Set<String> _activePointIds = {};
  final Set<String> _activeConnectionIds = {};

  @override
  void initState() {
    super.initState();

    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      zoom: 0.5,
      surface: const NetworkImage('https://unpkg.com/three-globe/example/img/earth-night.jpg'),
    );

    _globeController.onLoaded = () {
      if (mounted) {
        setState(() {
          _isGlobeLoaded = true;
        });
        _updateGlobePoints();
      }
    };

    _initRealGnssData();
  }

  @override
  void dispose() {
    _gnssSubscription?.cancel();
    _mockTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // LẤY DỮ LIỆU GNSS THỰC TẾ
  // ==========================================================
  Future<void> _initRealGnssData() async {
    var permission = await Permission.locationWhenInUse.request();

    if (permission.isGranted) {
      try {
        setState(() {
          _userLocation = UserLocationData(latitude: 21.028511, longitude: 105.804817);
        });
        _updateGlobePoints();

        _gnssSubscription = _gnssChannel.receiveBroadcastStream().listen((event) {
          if (!mounted) return;

          final List<dynamic> rawList = event as List<dynamic>;

          if (rawList.isEmpty && !_isUsingRealData) return;

          final random = Random();
          List<SatelliteData> realSats = [];

          for (var sat in rawList) {
            realSats.add(SatelliteData(
              prn: sat['svid'] ?? 0,
              elevation: (sat['elevationDegrees'] ?? 0.0).toDouble(),
              azimuth: (sat['azimuthDegrees'] ?? 0.0).toDouble(),
              snr: (sat['cn0DbHz'] ?? 0.0).toDouble(),
              system: _getConstellationName(sat['constellationType'] ?? 0),
              usedInFix: sat['usedInFix'] ?? false,
            ));
          }

          setState(() {
            _satellites = realSats;
            _isUsingRealData = true;
          });
          _updateGlobePoints();

          _mockTimer?.cancel();
        }, onError: (err) {
          _startMockDataFallback();
        });

        _startMockDataFallback();

      } catch (e) {
        _startMockDataFallback();
      }
    } else {
      _startMockDataFallback();
    }
  }

  // ==========================================================
  // HÀM CẮM GHIM VÀ VẼ TIA LASER TRÊN 3D GLOBE
  // ==========================================================
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

    // 1. CẮM GHIM VỊ TRÍ CỦA BẠN
    if (_userLocation != null) {
      const String userId = 'user_location';
      _globeController.addPoint(
        Point(
          id: userId,
          coordinates: GlobeCoordinates(_userLocation!.latitude, _userLocation!.longitude),
          label: 'Vị trí của bạn',
          isLabelVisible: true,
          style: const PointStyle(color: Colors.blueAccent, size: 8),
        ),
      );
      _activePointIds.add(userId);
    }

    // 2. VẼ VỆ TINH VÀ TIA LASER
    var topSats = _satellites.where((s) => s.usedInFix).toList();
    topSats.sort((a, b) => b.snr.compareTo(a.snr));
    var displaySats = topSats.take(5).toList();

    for (var sat in displaySats) {
      Color satColor = sat.system == "GPS" ? Colors.blueAccent : (sat.system == "GLONASS" ? Colors.redAccent : Colors.orangeAccent);

      double offsetLat = (90 - sat.elevation) * cos(sat.azimuth * pi / 180) * 0.15;
      double offsetLng = (90 - sat.elevation) * sin(sat.azimuth * pi / 180) * 0.15;

      GlobeCoordinates satCoords = GlobeCoordinates(
          (_userLocation?.latitude ?? 0) + offsetLat,
          (_userLocation?.longitude ?? 0) + offsetLng
      );

      final String satId = 'sat_${sat.prn}';
      _globeController.addPoint(
        Point(
          id: satId,
          coordinates: satCoords,
          label: 'PRN ${sat.prn}',
          isLabelVisible: true,
          style: PointStyle(color: satColor, size: 5),
        ),
      );
      _activePointIds.add(satId);

      if (_userLocation != null) {
        final String connId = 'conn_${sat.prn}';
        _globeController.addPointConnection(
            PointConnection(
              id: connId,
              start: GlobeCoordinates(_userLocation!.latitude, _userLocation!.longitude),
              end: satCoords,
              isLabelVisible: false,
            )
        );
        _activeConnectionIds.add(connId);
      }
    }
  }

  String _getConstellationName(int type) {
    switch (type) {
      case 1: return "GPS";
      case 2: return "SBAS";
      case 3: return "GLONASS";
      case 4: return "QZSS";
      case 5: return "BEIDOU";
      case 6: return "GALILEO";
      case 7: return "IRNSS";
      default: return "KHÔNG RÕ";
    }
  }

  void _startMockDataFallback() {
    if (_mockTimer != null && _mockTimer!.isActive) return;

    final random = Random();
    List<SatelliteData> sats = [];
    for (int i = 0; i < 12; i++) {
      String sys = i % 3 == 0 ? "GLONASS" : (i % 4 == 0 ? "GALILEO" : "GPS");
      sats.add(SatelliteData(
        prn: i + 10,
        elevation: random.nextDouble() * 80 + 10,
        azimuth: random.nextDouble() * 360,
        snr: random.nextDouble() * 25 + 20,
        system: sys,
        usedInFix: random.nextDouble() > 0.3,
      ));
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
        ? _satellites.map((s) => s.snr).reduce((a, b) => a + b) / _satellites.length
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Nền Starfield
          Positioned.fill(child: CustomPaint(painter: StarFieldPainter())),
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.1)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildStatsOverview(activeFixes, avgSnr),

                // VÙNG RENDER TRÁI ĐẤT 3D
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_showGlobe)
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.width,
                          child: FlutterEarthGlobe(
                            controller: _globeController,
                            radius: 140, // Độ lớn Trái đất
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: CustomPaint(size: Size.infinite, painter: SkyplotPainter(_satellites)),
                        ),

                      _buildViewToggle(),
                    ],
                  ),
                ),
                _buildBottomPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70)),
          Column(
            children: [
              const Text("ĐỊNH VỊ VỆ TINH", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
              Text(
                  _isUsingRealData ? "DỮ LIỆU GNSS TRỰC TIẾP" : "DỮ LIỆU MÔ PHỎNG (MẤT SÓNG)",
                  style: TextStyle(color: _isUsingRealData ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)
              ),
            ],
          ),
          Icon(Icons.settings_input_antenna_rounded, color: _isUsingRealData ? Colors.greenAccent : Colors.white24),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(int activeFixes, double avgSnr) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("TRONG TẦM NHÌN", "${_satellites.length}", Colors.blueAccent),
          _buildStatItem("ĐANG SỬ DỤNG", "$activeFixes", Colors.greenAccent),
          _buildStatItem("SNR TRUNG BÌNH", "${avgSnr.toStringAsFixed(1)} dB", Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Positioned(
      bottom: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton("ĐỊA CẦU", _showGlobe, () => setState(() => _showGlobe = true)),
            _buildToggleButton("RADAR", !_showGlobe, () => setState(() => _showGlobe = false)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Text("DANH SÁCH VỆ TINH (TÍN HIỆU dBHz)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  scrollDirection: Axis.horizontal,
                  itemCount: _satellites.length,
                  itemBuilder: (context, index) => _buildSatelliteCard(_satellites[index]),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSatelliteCard(SatelliteData sat) {
    Color color = sat.system == "GPS" ? Colors.blueAccent : (sat.system == "GLONASS" ? Colors.redAccent : Colors.orangeAccent);
    if (!sat.usedInFix) color = Colors.grey;

    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${sat.prn}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Icon(Icons.bolt, color: color, size: 14),
            ],
          ),
          const Spacer(),
          Container(
            height: 40, width: 8,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (sat.snr / 50).clamp(0, 1),
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ),
          const Spacer(),
          Text(sat.system, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text("${sat.snr.toInt()} dB", style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}

// --- Các lớp cơ bản khác ---
class SkyplotPainter extends CustomPainter {
  final List<SatelliteData> satellites;
  SkyplotPainter(this.satellites);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    final radarPaint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, radarPaint);

    final linePaint = Paint()..color = Colors.white.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(center, maxRadius, linePaint);
    canvas.drawCircle(center, maxRadius * 0.66, linePaint);
    canvas.drawCircle(center, maxRadius * 0.33, linePaint);

    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), linePaint);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), linePaint);

    for (var sat in satellites) {
      double r = maxRadius * ((90 - sat.elevation) / 90);
      double theta = (sat.azimuth - 90) * pi / 180;
      double x = center.dx + r * cos(theta);
      double y = center.dy + r * sin(theta);
      Color color = sat.system == "GPS" ? Colors.blueAccent : (sat.system == "GLONASS" ? Colors.redAccent : Colors.orangeAccent);
      if (!sat.usedInFix) color = Colors.grey;

      canvas.drawCircle(Offset(x, y), 6, Paint()..color = color);
      if (sat.usedInFix) {
        canvas.drawCircle(Offset(x, y), 10, Paint()..color = color.withOpacity(0.2));
      }

      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(text: "${sat.prn}", style: const TextStyle(color: Colors.white70, fontSize: 9));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 8, y));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 100; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = random.nextDouble() * 1.2;
      double opacity = random.nextDouble() * 0.5 + 0.1;
      canvas.drawCircle(Offset(x, y), radius, paint..color = Colors.white.withOpacity(opacity));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}