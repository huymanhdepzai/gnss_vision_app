import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import '../../domain/entities/satellite_data.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../widgets/satellite_drawer.dart';
import 'satellite_detail_page.dart';
import 'satellite_export_list_page.dart';
import '../widgets/gnss_analysis_view.dart';

enum SatelliteViewMode { globe, radar, analysis }

class UserLocationData {
  final double latitude;
  final double longitude;
  UserLocationData({required this.latitude, required this.longitude});
}

class StarModel {
  final double x;
  final double y;
  final double size;
  final double twinkleSpeed;
  final double twinkleOffset;
  final bool isBright;

  StarModel({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinkleOffset,
    this.isBright = false,
  });
}

class SatelliteScreenV2 extends StatefulWidget {
  const SatelliteScreenV2({super.key});

  @override
  State<SatelliteScreenV2> createState() => _SatelliteScreenV2State();
}

class _SatelliteScreenV2State extends State<SatelliteScreenV2>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<SatelliteData> _satellites = [];
  UserLocationData? _userLocation;
  final List<StarModel> _stars = [];
  
  // History tracking for analysis
  final List<Map<String, dynamic>> _gnssHistory = [];
  static const int _maxHistoryPoints = 60; // Approx 1-2 minutes of history

  StreamSubscription? _gnssSubscription;
  Timer? _mockTimer;

  SatelliteViewMode _viewMode = SatelliteViewMode.globe;
  bool _isUsingRealData = false;
  bool _isGlobeLoaded = false;
  String _filterSystem = 'ALL';

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _radarSweepController;

  late Animation<double> _pulseAnimation;

  static const EventChannel _gnssChannel = EventChannel('gnss_status_channel');

  late FlutterEarthGlobeController _globeController;
  final Set<String> _activePointIds = {};
  final Set<String> _activeConnectionIds = {};

  

  @override
  void initState() {
    super.initState();
    _initStars();
    _initAnimations();
    _initGlobeController();
    _initRealGnssData();
  }

  void _initStars() {
    final random = Random();
    // Background stars
    for (int i = 0; i < 100; i++) {
      _stars.add(StarModel(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 1.5 + 0.5,
        twinkleSpeed: random.nextDouble() * 2 + 1,
        twinkleOffset: random.nextDouble() * pi * 2,
      ));
    }
    // Bright stars
    for (int i = 0; i < 15; i++) {
      _stars.add(StarModel(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 1.5,
        twinkleSpeed: random.nextDouble() * 4 + 2,
        twinkleOffset: random.nextDouble() * pi * 2,
        isBright: true,
      ));
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initGlobeController() {
    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.005,
      isRotating: true,
      zoom: 0.5,
      surface: const AssetImage('assets/images/earth-night.jpg'),
      isDayNightCycleEnabled: false,
    );

    _globeController.onLoaded = () {
      if (mounted) {
        setState(() => _isGlobeLoaded = true);
        _updateGlobePoints();
      }
    };

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isGlobeLoaded) {
        setState(() => _isGlobeLoaded = true);
        _updateGlobePoints();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _radarSweepController.dispose();
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

            List<SatelliteData> realSats = [];

            for (var sat in rawList) {
              realSats.add(
                SatelliteData(
                  prn: sat['svid'] ?? 0,
                  elevation:
                      (sat['elevationDegrees'] ?? 0.0).toDouble(),
                  azimuth: (sat['azimuthDegrees'] ?? 0.0).toDouble(),
                  snr: (sat['cn0DbHz'] ?? 0.0).toDouble(),
                  system:
                      _getConstellationName(sat['constellationType'] ?? 0),
                  usedInFix: sat['usedInFix'] ?? false,
                ),
              );
            }

            setState(() {
              _satellites = realSats;
              _isUsingRealData = true;
              _updateGnssHistory();
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

  void _updateGnssHistory() {
    if (_satellites.isEmpty) return;
    
    final avgSnr = _satellites.map((s) => s.snr).reduce((a, b) => a + b) / _satellites.length;
    final usedInFix = _satellites.where((s) => s.usedInFix).length;
    
    _gnssHistory.add({
      'timestamp': DateTime.now(),
      'avgSnr': avgSnr,
      'usedInFix': usedInFix,
      'total': _satellites.length,
    });
    
    if (_gnssHistory.length > _maxHistoryPoints) {
      _gnssHistory.removeAt(0);
    }
  }

  List<SatelliteData> get _filteredSatellites {
    if (_filterSystem == 'ALL') return _satellites;
    return _satellites.where((s) => s.system == _filterSystem).toList();
  }

  Map<String, int> get _constellationCounts {
    final counts = <String, int>{};
    for (var s in _satellites) {
      counts[s.system] = (counts[s.system] ?? 0) + 1;
    }
    return counts;
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
          style: const PointStyle(color: Colors.cyanAccent, size: 2),
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
    return kSatelliteSystemColors[system] ?? Colors.white;
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

  String _getSignalQuality(double avgSnr) {
    if (avgSnr >= 35) return 'Xuất sắc';
    if (avgSnr >= 25) return 'Tốt';
    if (avgSnr >= 15) return 'Trung bình';
    return 'Yếu';
  }

  Color _getSignalQualityColor(double avgSnr) {
    if (avgSnr >= 35) return AppTheme.successColor;
    if (avgSnr >= 25) return AppTheme.secondaryColor;
    if (avgSnr >= 15) return AppTheme.warningColor;
    return AppTheme.accentColor;
  }

  Future<void> _exportRawData() async {
    if (_satellites.isEmpty) {
      context.showModernSnackBar(
        message: 'Không có dữ liệu vệ tinh để xuất',
        icon: Icons.warning_amber_rounded,
        color: context.warningColor,
      );
      return;
    }

    // 1. Ask for filename
    final now = DateTime.now();
    final defaultFileName = 'GNSS_RAW_${DateFormat('yyyyMMdd_HHmmss').format(now)}';
    
    final fileName = await context.showModernDialog<String>(
      child: ModernInputDialog(
        title: 'Đặt tên tệp',
        subtitle: 'Dữ liệu sẽ được xuất dưới định dạng .csv',
        hintText: 'Tên tệp',
        initialValue: defaultFileName,
        confirmLabel: 'TIẾP THEO',
      ),
    );

    if (fileName == null || fileName.isEmpty) return;

    // 2. Ask for save location
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Chọn nơi lưu tệp',
    );

    if (selectedDirectory == null) return;

    try {
      final fullFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
      
      String csvContent = 'Timestamp,SVID,System,Elevation,Azimuth,SNR,UsedInFix\n';
      final timestamp = now.toIso8601String();
      
      for (var sat in _satellites) {
        csvContent += '$timestamp,${sat.prn},${sat.system},${sat.elevation.toStringAsFixed(2)},${sat.azimuth.toStringAsFixed(2)},${sat.snr.toStringAsFixed(2)},${sat.usedInFix}\n';
      }

      final file = File('$selectedDirectory/$fullFileName');
      await file.writeAsString(csvContent);

      // Also save a copy to app docs for the internal list
      final appDir = await getApplicationDocumentsDirectory();
      // Ensure we use a GNSS_ prefix if we want it to show up in the list (as per our list filter)
      final internalFileName = fullFileName.startsWith('GNSS_') ? fullFileName : 'GNSS_$fullFileName';
      await File('${appDir.path}/$internalFileName').writeAsString(csvContent);

      if (mounted) {
        context.showModernSnackBar(
          message: 'Đã lưu tệp thành công!',
          icon: Icons.check_circle_rounded,
          color: context.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showModernSnackBar(
          message: 'Lỗi khi lưu tệp: $e',
          icon: Icons.error_outline_rounded,
          color: context.errorColor,
        );
      }
    }
  }

  void _startMockDataFallback() {
    if (_mockTimer != null && _mockTimer!.isActive) return;

    final random = Random();
    List<SatelliteData> sats = [];
    for (int i = 0; i < 12; i++) {
      String sys =
          i % 3 == 0 ? "GLONASS" : (i % 4 == 0 ? "GALILEO" : "GPS");
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
      setState(() {
        _satellites = sats;
        _updateGnssHistory();
      });
      _updateGlobePoints();
    }

    _mockTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isUsingRealData) return;
      setState(() {
        _satellites = _satellites.map((s) {
          return SatelliteData(
            prn: s.prn,
            elevation: (s.elevation + 0.02) % 90,
            azimuth: (s.azimuth + 0.05) % 360,
            snr: (s.snr + random.nextDouble() * 0.4 - 0.2).clamp(10.0, 50.0),
            system: s.system,
            usedInFix: s.usedInFix,
          );
        }).toList();
        _updateGnssHistory();
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

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: context.backgroundColor,
            endDrawer: SatelliteDrawer(
              satellites: _satellites,
              filteredSatellites: _filteredSatellites,
              filterSystem: _filterSystem,
              onFilterChanged: (sys) => setState(() => _filterSystem = sys),
              onExportRawData: _exportRawData,
            ),
            body: Stack(
              children: [
                _buildAnimatedBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(context),
                      if (_viewMode != SatelliteViewMode.analysis) ...[
                        SizedBox(height: UIConsts.spacingSM),
                        _buildStatsOverview(context, activeFixes, avgSnr),
                      ],
                      Expanded(child: _buildMainView(context)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return CustomPaint(
          painter: AnimatedStarFieldPainter(_shimmerController.value, _stars),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      duration: UIConsts.animEntrance,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: UIConsts.spacingLG,
          vertical: UIConsts.spacingSM,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: UIConsts.spacingLG,
          vertical: UIConsts.spacingMD,
        ),
        decoration: AppTheme.glassDecoration(isDark: context.isDark),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PressScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(UIConsts.spacingSM),
                decoration: BoxDecoration(
                  color: context.adaptiveOpacity(Colors.white, 0.1, 0.06),
                  borderRadius: BorderRadius.circular(UIConsts.radiusMD),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.iconColor,
                  size: UIConsts.iconSizeSM,
                ),
              ),
            ),
            const SizedBox(width: UIConsts.spacingSM),
            Flexible(
              child: Center(
                child: _buildTitleSection(context),
              ),
            ),
            const SizedBox(width: UIConsts.spacingSM),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // _buildStatusIndicator(context),
                SizedBox(width: UIConsts.spacingSM),
                PressScale(
                  onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                  child: Container(
                    padding: EdgeInsets.all(UIConsts.spacingSM),
                    decoration: BoxDecoration(
                      color: context.adaptiveOpacity(Colors.white, 0.1, 0.06),
                      borderRadius: BorderRadius.circular(UIConsts.radiusMD),
                    ),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: context.iconColor,
                      size: UIConsts.iconSizeSM,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
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
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    return BreathingGlow(
      glowColor: _isUsingRealData ? AppTheme.successColor : Colors.white24,
      minOpacity: 0.1,
      maxOpacity: 0.3,
      child: Container(
        padding: EdgeInsets.all(UIConsts.spacingMD - 2),
        decoration: BoxDecoration(
          color: context.adaptiveOpacity(Colors.white, 0.05, 0.03),
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          border: Border.all(
            color: _isUsingRealData
                ? AppTheme.successColor.withOpacity(0.3)
                : context.adaptiveOpacity(Colors.white, 0.15, 0.1),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.settings_input_antenna_rounded,
          color: _isUsingRealData ? AppTheme.successColor : context.iconSecondaryColor,
          size: UIConsts.iconSizeMD,
        ),
      ),
    );
  }

  Widget _buildStatsOverview(
      BuildContext context, int activeFixes, double avgSnr) {
    final qualityColor = _getSignalQualityColor(avgSnr);
    final qualityLabel = _getSignalQuality(avgSnr);
    final signalQuality = avgSnr / 50.0;
    final counts = _constellationCounts;
    final systems = ['GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];

    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      delay: const Duration(milliseconds: 100),
      duration: UIConsts.animEntrance,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingLG),
        child: ModernCard(
          accentColor: qualityColor,
          hasGlow: true,
          padding: EdgeInsets.symmetric(
            vertical: UIConsts.spacingLG,
            horizontal: UIConsts.spacingLG,
          ),
          child: Row(
            children: [
              _buildSignalQualityGauge(signalQuality, qualityColor),
              SizedBox(width: UIConsts.spacingMD),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    qualityLabel,
                    style: TextStyle(
                      color: qualityColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: UIConsts.spacingXS),
                  Text(
                    'SNR: ${avgSnr.toStringAsFixed(1)} dB-Hz',
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: systems.map((sys) {
                      final count = counts[sys] ?? 0;
                      final color = kSatelliteSystemColors[sys] ?? Colors.white;
                      return Padding(
                        padding: EdgeInsets.only(left: UIConsts.spacingMD),
                        child: Column(
                          children: [
                            Text(
                              count.toString(),
                              style: TextStyle(
                                color: color,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              sys,
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalQualityGauge(double quality, Color color) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(48, 48),
          painter: SignalQualityGaugePainter(
            progress: quality.clamp(0.0, 1.0),
            color: color,
            shimmerValue: _shimmerController.value,
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        SizedBox(height: UIConsts.spacingSM),
        AnimatedCounter(
          value: int.parse(value.isEmpty ? "0" : value),
          duration: UIConsts.animNormal,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            shadows: [
              Shadow(color: color.withOpacity(0.5), blurRadius: 10),
            ],
          ),
        ),
        SizedBox(height: UIConsts.spacingXS),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMainView(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedSwitcher(
          duration: UIConsts.animSlow,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale:
                    Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: _viewMode == SatelliteViewMode.globe
              ? _buildGlobeView(context)
              : _viewMode == SatelliteViewMode.radar
                  ? _buildRadarView(context)
                  : GnssAnalysisView(
                      satellites: _satellites,
                      history: _gnssHistory,
                    ),
        ),
        _buildViewToggle(context),
      ],
    );
  }

  Widget _buildGlobeView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Transform.translate(
          offset: const Offset(0, -60), // Nhích trái đất lên trên để thu hẹp khoảng cách với phần trên
          child: Stack(
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
                          AppTheme.primaryColor.withOpacity(0.05),
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
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: FlutterEarthGlobe(
                    controller: _globeController,
                    radius: 120,
                  ),
                ),
              ),

              if (!_isGlobeLoaded) _buildLoadingIndicator(context),
              if (_isGlobeLoaded) ...[
                _buildOrbitalRings(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConstellationLegend(BuildContext context) {
    final counts = _constellationCounts;
    final systems = ['GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];

    return Positioned(
      top: UIConsts.spacingSM,
      left: UIConsts.spacingSM,
      child: EntranceAnimation(
        type: EntranceType.fadeSlideRight,
        delay: const Duration(milliseconds: 400),
        child: Container(
          padding: EdgeInsets.all(UIConsts.spacingSM),
          decoration: AppTheme.cardDecoration(
            isDark: context.isDark,
            accentColor: AppTheme.primaryColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HỆ THỐNG',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: UIConsts.spacingSM - 2),
              ...systems.map((sys) {
                final count = counts[sys] ?? 0;
                final color = kSatelliteSystemColors[sys] ?? Colors.white;
                return Padding(
                  padding: EdgeInsets.only(bottom: UIConsts.spacingXS),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: UIConsts.spacingSM),
                      Text(
                        sys,
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: UIConsts.spacingSM),
                      ModernBadge(
                        count: count,
                        color: color,
                        fontSize: 9,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitalRings() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return CustomPaint(
              painter: OrbitalRingsPainter(_pulseController.value),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRadarView(BuildContext context) {
    return Padding(
      key: const ValueKey('radar'),
      padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingLG),
      child: Container(
        decoration: AppTheme.glassDecoration(isDark: context.isDark),
        padding: EdgeInsets.all(UIConsts.spacingLG),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConsts.radius2XL),
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: ModernRadarPainter(
                  _satellites,
                  _pulseController,
                  _radarSweepController,
                ),
              ),
              _buildRadarCompassLabels(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarCompassLabels() {
    final compassDirs = [
      CompassLabel('N', Alignment.topCenter, Icons.arrow_upward_rounded),
      CompassLabel('S', Alignment.bottomCenter, Icons.arrow_downward_rounded),
      CompassLabel('E', Alignment.centerRight, Icons.arrow_forward_rounded),
      CompassLabel('W', Alignment.centerLeft, Icons.arrow_back_rounded),
    ];

    return Stack(
      children: compassDirs.map((dir) {
        return Align(
          alignment: dir.alignment,
          child: Container(
            margin: EdgeInsets.all(UIConsts.spacingXS),
            padding: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingSM,
              vertical: UIConsts.spacingXS,
            ),
            decoration: BoxDecoration(
              color: context.cardColor.withOpacity(0.85),
              borderRadius: BorderRadius.circular(UIConsts.spacingSM),
              border: Border.all(
                color: AppTheme.secondaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              dir.label,
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.adaptiveOpacity(Colors.white, 0.05, 0.02),
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
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.1),
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
            SizedBox(height: UIConsts.spacingLG),
            Text(
              "Đang tải địa cầu...",
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Positioned(
      bottom: UIConsts.spacingSM,
      child: Container(
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.adaptiveOpacity(Colors.white, 0.06, 0.04),
          borderRadius: BorderRadius.circular(UIConsts.radiusFull),
          border: Border.all(
            color: context.adaptiveOpacity(Colors.white, 0.1, 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              context,
              "ĐỊA CẦU",
              Icons.public_rounded,
              _viewMode == SatelliteViewMode.globe,
              () => _switchView(SatelliteViewMode.globe),
            ),
            _buildToggleButton(
              context,
              "SKYPLOT",
              Icons.radar_rounded,
              _viewMode == SatelliteViewMode.radar,
              () => _switchView(SatelliteViewMode.radar),
            ),
            _buildToggleButton(
              context,
              "PHÂN TÍCH",
              Icons.analytics_rounded,
              _viewMode == SatelliteViewMode.analysis,
              () => _switchView(SatelliteViewMode.analysis),
            ),
          ],
        ),
      ),
    );
  }

  void _switchView(SatelliteViewMode mode) {
    HapticFeedback.lightImpact();
    setState(() => _viewMode = mode);
  }

  Widget _buildToggleButton(
    BuildContext context,
    String text,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UIConsts.animNormal,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: UIConsts.spacingLG,
          vertical: UIConsts.spacingSM + 2,
        ),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(UIConsts.radiusFull - 2),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.0 : 0.9,
              duration: UIConsts.animNormal,
              child: Icon(
                icon,
                color: active
                    ? Colors.white
                    : context.iconSecondaryColor,
                size: UIConsts.iconSizeSM - 2,
              ),
            ),
            SizedBox(width: UIConsts.spacingSM - 2),
            Text(
              text,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : context.iconSecondaryColor,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingXL),
        children: kFilterSystems.map((sys) {
          final isActive = _filterSystem == sys;
          final color = sys == 'ALL'
              ? AppTheme.primaryColor
              : (kSatelliteSystemColors[sys] ?? Colors.white);
          final count = sys == 'ALL'
              ? _satellites.length
              : _satellites.where((s) => s.system == sys).length;
          final label = kSatelliteSystemLabels[sys] ?? sys;

          return Padding(
            padding: EdgeInsets.only(right: UIConsts.spacingSM),
            child: ModernChip(
              label: '$label $count',
              color: color,
              isSelected: isActive,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _filterSystem = sys);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSatelliteListSheet(BuildContext context) {
    context.showModernBottomSheet(
      maxHeightRatio: 0.7,
      child: ModernBottomSheet(
        title: "DANH SÁCH VỆ TINH",
        accentColor: AppTheme.primaryColor,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: UIConsts.spacingXL,
                  vertical: UIConsts.spacingSM),
              child: Row(
                children: [
                  ModernBadge(
                    text: "${_satellites.length} vệ tinh",
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                    horizontal: UIConsts.spacingXL),
                itemCount: _satellites.length,
                itemBuilder: (context, index) {
                  final sat = _satellites[index];
                  return SatelliteListItem(
                    sat: sat,
                    index: index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteCard(
      BuildContext context, SatelliteData sat, int index) {
    Color color = _getSatelliteColor(sat.system);
    if (!sat.usedInFix) color = Colors.grey;

    return EntranceAnimation(
      delay: Duration(milliseconds: index * 80),
      duration: const Duration(milliseconds: 500),
      type: EntranceType.scaleFade,
      child: PressScale(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SatelliteDetailScreen(satellite: sat, themeColor: color),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: UIConsts.animSlow,
            ),
          );
        },
        child: Container(
          width: 120,
          margin: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingSM - 2,
              vertical: UIConsts.spacingXS),
          padding: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingMD,
              vertical: UIConsts.spacingSM),
          decoration: AppTheme.cardDecoration(
            isDark: context.isDark,
            accentColor: sat.usedInFix ? color : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardHeader(sat, color),
              _buildSignalBar(sat, color, context),
              _buildCardFooter(sat, color, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(SatelliteData sat, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Hero(
          tag: 'sat_prn_${sat.prn}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              "#${sat.prn}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Hero(
          tag: 'sat_icon_${sat.prn}',
          child: ModernIconContainer(
            icon: sat.usedInFix ? Icons.bolt_rounded : Icons.bolt_outlined,
            color: color,
            size: 24,
            iconSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalBar(SatelliteData sat, Color color, BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: UIConsts.spacingXS),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            double fillHeight = ((sat.snr / 50) * 5 - i).clamp(0.0, 1.0);
            return Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                color:
                    context.adaptiveOpacity(Colors.white, 0.1, 0.05),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      width: 6,
                      height: 28 * fillHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color, color.withOpacity(0.5)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.5), blurRadius: 5),
                        ],
                      ),
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

  Widget _buildCardFooter(
      SatelliteData sat, Color color, BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingSM - 2,
              vertical: UIConsts.spacingXS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(UIConsts.spacingSM),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sat.system,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: UIConsts.spacingXS),
              Icon(Icons.height_rounded,
                  color: color.withOpacity(0.6),
                  size: UIConsts.iconSizeXS),
              Text(
                "${sat.elevation.toStringAsFixed(0)}°",
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: UIConsts.spacingXS),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${sat.snr.toInt()}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              " dB",
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CompassLabel {
  final String label;
  final Alignment alignment;
  final IconData icon;

  CompassLabel(this.label, this.alignment, this.icon);
}

class SignalQualityGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double shimmerValue;

  SignalQualityGaugePainter({
    required this.progress,
    required this.color,
    required this.shimmerValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = -pi * 0.75;
    const sweepAngle = pi * 1.5;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final progressAngle = sweepAngle * progress.clamp(0.0, 1.0);

    final gradientPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + progressAngle,
        colors: [color.withOpacity(0.6), color],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressAngle,
      false,
      gradientPaint,
    );

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final endAngle = startAngle + progressAngle;
    final endX = center.dx + radius * cos(endAngle);
    final endY = center.dy + radius * sin(endAngle);

    canvas.drawCircle(Offset(endX, endY), 8, glowPaint);
    canvas.drawCircle(Offset(endX, endY), 4, Paint()..color = color);
    canvas.drawCircle(Offset(endX, endY), 2, Paint()..color = Colors.white);

    final percentText = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    percentText.paint(canvas, Offset(
      center.dx - percentText.width / 2,
      center.dy - percentText.height / 2,
    ));
  }

  @override
  bool shouldRepaint(covariant SignalQualityGaugePainter oldDelegate) => true;
}

class AnimatedStarFieldPainter extends CustomPainter {
  final double animationValue;
  final List<StarModel> stars;

  AnimatedStarFieldPainter(this.animationValue, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      final x = star.x * size.width;
      final y = star.y * size.height;
      
      // Advanced organic twinkle logic using individual star properties
      // Mix of two sine waves for more irregular, natural feel
      double twinkle = sin(animationValue * pi * star.twinkleSpeed + star.twinkleOffset) * 0.5 + 0.5;
      
      if (star.isBright) {
        // Bright stars with subtle glow
        final opacity = (0.3 + twinkle * 0.4).clamp(0.0, 1.0);
        
        // Outer glow
        canvas.drawCircle(
          Offset(x, y), 
          star.size * 2.5, 
          Paint()
            ..color = Colors.white.withOpacity(opacity * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        );
        
        // Core
        canvas.drawCircle(
          Offset(x, y), 
          star.size, 
          Paint()..color = Colors.white.withOpacity(opacity)
        );
      } else {
        // Dim background stars
        final opacity = (0.1 + twinkle * 0.2).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(x, y), 
          star.size, 
          Paint()..color = Colors.white.withOpacity(opacity)
        );
      }
    }

    // Occasional subtle nebula pulse (using global animation)
    final nebulaOpacity = (sin(animationValue * pi) * 0.02 + 0.03).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(nebulaOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.2), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 120, paint);
  }

  @override
  bool shouldRepaint(covariant AnimatedStarFieldPainter oldDelegate) => 
    oldDelegate.animationValue != animationValue;
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
      double rotation = animationValue * pi * 0.5 + (i * pi / 3);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);

      final paint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.05)
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
  final AnimationController sweepController;

  ModernRadarPainter(
    this.satellites,
    this.pulseController,
    this.sweepController,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 30;

    _drawRadarBackground(canvas, center, maxRadius);
    _drawGridLines(canvas, center, maxRadius);
    _drawGridLabels(canvas, center, maxRadius);
    _drawRadialLines(canvas, center, maxRadius);
    _drawSweepingLine(canvas, center, maxRadius);
    _drawSatellites(canvas, center, maxRadius);
    _drawCenterPulse(canvas, center);
  }

  void _drawRadarBackground(Canvas canvas, Offset center, double radius) {
    final gradient = RadialGradient(
      colors: [AppTheme.primaryColor.withOpacity(0.08), Colors.transparent],
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
    final elevations = [
      (30.0, '30°'),
      (60.0, '60°'),
    ];

    for (int i = 1; i <= 3; i++) {
      final r = radius * i / 3;
      final paint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawCircle(center, r, paint);
    }

    for (var entry in elevations) {
      final r = radius * ((90 - entry.$1) / 90);
      final labelPainter = TextPainter(
        text: TextSpan(
          text: entry.$2,
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(canvas,
          Offset(center.dx + 4, center.dy - r - labelPainter.height - 2));
    }
  }

  void _drawGridLabels(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppTheme.secondaryColor.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _drawRadialLines(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 12; i++) {
      double angle = (i * 30) * pi / 180;
      final paint = Paint()
        ..color =
            Colors.white.withOpacity(i % 3 == 0 ? 0.08 : 0.04)
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
    double sweepAngle = (sweepController.value * 360) * pi / 180;

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - 0.8,
      endAngle: sweepAngle,
      colors: [
        Colors.transparent,
        AppTheme.secondaryColor.withOpacity(0.15),
        AppTheme.secondaryColor.withOpacity(0.05),
      ],
      transform: GradientRotation(sweepAngle - pi / 2),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient
          .createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - pi / 2 - 0.8,
      0.8,
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
        ..color = AppTheme.secondaryColor.withOpacity(0.4)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
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
          10 + pulseController.value * 3,
          Paint()..color = color.withOpacity(0.06),
        );
        canvas.drawCircle(
          Offset(x, y),
          7 + pulseController.value * 2,
          Paint()..color = color.withOpacity(0.08),
        );
      }

      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = color.withOpacity(0.3),
      );

      final satPaint = Paint()..color = color;
      satPaint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5, satPaint);

      canvas.drawCircle(
          Offset(x, y), 3, Paint()..color = Colors.white.withOpacity(0.8));

      final textPainter = TextPainter(
        text: TextSpan(
          text: "${sat.prn}",
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x + 9, y - 5));
    }
  }

  void _drawCenterPulse(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      8 + pulseController.value * 4,
      Paint()..color = AppTheme.secondaryColor.withOpacity(0.06),
    );
    canvas.drawCircle(
      center,
      6,
      Paint()..color = AppTheme.secondaryColor.withOpacity(0.12),
    );
    canvas.drawCircle(center, 4,
        Paint()..color = AppTheme.secondaryColor.withOpacity(0.5));
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

Color _getSatelliteColor(String system) {
    return kSatelliteSystemColors[system] ?? Colors.white;
  }

  @override
  bool shouldRepaint(covariant ModernRadarPainter oldDelegate) => true;
}