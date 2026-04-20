import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../vision/presentation/pages/satellite_page.dart';
import '../../../vision/presentation/pages/flow_page.dart';
import '../../../map/presentation/controllers/navigation_controller.dart';
import '../../../vision/presentation/pages/navigation_vision_page.dart';
import '../../../map/domain/entities/navigation_route.dart';
import '../../../map/domain/entities/navigation_step.dart';
import '../../../trip/presentation/pages/trip_manager_page.dart';
import '../widgets/app_drawer.dart';

enum MapState { explore, placeDetail, navigating }

class MapHomeScreenV2 extends StatefulWidget {
  const MapHomeScreenV2({Key? key}) : super(key: key);

  @override
  State<MapHomeScreenV2> createState() => _MapHomeScreenV2State();
}

class _MapHomeScreenV2State extends State<MapHomeScreenV2>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;

  MapState _currentState = MapState.explore;

  Position _currentLocation = Position(105.804817, 21.028511);
  bool _isLocationLoaded = false;
  StreamSubscription<geo.Position>? _positionStream;

  String _destinationName = "";
  String _destinationAddress = "";
  Position? _destinationLocation;

  String _distance = "Đang tính...";
  String _duration = "-- phút";

  String? _routeGeoJson;
  bool _isRouteActive = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  late AnimationController _fabAnimationController;
  late AnimationController _sheetAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _sheetSlideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _getUserLocation();
    _initVoiceController();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _initVoiceController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceController = context.read<VoiceController>();
      voiceController.onCommandRecognized = _handleVoiceCommand;
      if (voiceController.isEnabled) {
        voiceController.initialize();
      }
    });
  }

  void _handleVoiceCommand(String command) {
    switch (command) {
      case 'gnss-vision':
        _navigateToVision();
        break;
      case 'satellite':
        Navigator.push(
          context,
          PageTransition(
            child: const SatelliteScreenV2(),
            type: PageTransitionType.fadeSlide,
            duration: const Duration(milliseconds: 600),
          ),
        );
        break;
      case 'home':
        Navigator.popUntil(context, (route) => route.isFirst);
        break;
    }
  }

  void _initAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _sheetSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _sheetAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fabAnimationController.forward();
    _startPulseAnimation();
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    _pulseController.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopPulseAnimation();
    } else if (state == AppLifecycleState.resumed) {
      _startPulseAnimation();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _debounce?.cancel();
    _fabAnimationController.dispose();
    _sheetAnimationController.dispose();
    _stopPulseAnimation();
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }

    if (permission == geo.LocationPermission.deniedForever) return;

    // Lấy vị trí hiện tại ngay lập tức để hiển thị trước
    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _updateLocationState(position);

      // Di chuyển camera đến vị trí vừa lấy được
      if (_mapboxMap != null) {
        _updateCamera(_currentLocation, 16.0);
      }
    } catch (e) {
      debugPrint("Lỗi lấy vị trí ban đầu: $e");
    }

    // Bắt đầu lắng nghe thay đổi vị trí liên tục
    _positionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 5, // Cập nhật mỗi khi di chuyển 5 mét
          ),
        ).listen((geo.Position position) {
          _updateLocationState(position);
        });
  }

  void _updateLocationState(geo.Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = Position(position.longitude, position.latitude);
      _isLocationLoaded = true;
    });

    // Cập nhật marker trên bản đồ
    _drawMarkers();

    // Nếu đang dẫn đường, tự động di chuyển camera theo người dùng
    if (_currentState == MapState.navigating && _mapboxMap != null) {
      _updateCamera(_currentLocation, 17.0);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';

    _mapboxMap?.loadStyleURI(
      'https://tiles.goong.io/assets/navigation_night.json?api_key=$mapTilesKey',
    );
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager = await _mapboxMap?.annotations
        .createCircleAnnotationManager();

    if (_isLocationLoaded) {
      _updateCamera(_currentLocation, 16.0);
      _drawMarkers();
    }

    if (_isRouteActive && _routeGeoJson != null) {
      await _drawRouteLine();
    }
  }

  Future<void> _drawRouteLine() async {
    if (_mapboxMap == null || _routeGeoJson == null) return;
    try {
      await _clearRouteOnly();
      await _mapboxMap?.style.addSource(
        GeoJsonSource(id: "route_source", data: _routeGeoJson!),
      );
      var lineLayerJson = """{
        "type": "line",
        "id": "route_layer",
        "source": "route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#00D4FF",
          "line-width": 6.0,
          "line-blur": 2.0
        }
      }""";
      await _mapboxMap?.style.addPersistentStyleLayer(lineLayerJson, null);
    } catch (e) {
      debugPrint("Lỗi vẽ đường đi: $e");
    }
  }

  Future<void> _clearRouteOnly() async {
    try {
      await _mapboxMap?.style.removeStyleLayer("route_layer");
      await _mapboxMap?.style.removeStyleSource("route_source");
    } catch (e) {}
  }

  void _updateCamera(Position position, double zoom) {
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: position).toJson(),
        zoom: zoom,
      ),
    );
  }

  Future<void> _drawMarkers() async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager?.deleteAll();

    if (_isLocationLoaded) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _currentLocation).toJson(),
          circleColor: AppTheme.secondaryColor.withOpacity(0.3).value,
          circleRadius: 20.0,
        ),
      );

      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _currentLocation).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    if (_currentState != MapState.explore && _destinationLocation != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _destinationLocation!).toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 12.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchPlaces(query);
      } else {
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/AutoComplete?api_key=$apiKey&input=${Uri.encodeComponent(query)}&location=${_currentLocation.lat},${_currentLocation.lng}&radius=50',
    );

    try {
      var response = await http.get(url);
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['predictions'] != null) {
        setState(() {
          _searchResults = jsonResponse['predictions'];
        });
      }
    } catch (e) {
      debugPrint("Lỗi tìm kiếm: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchController.text = description;
    });

    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/Detail?place_id=$placeId&api_key=$apiKey',
    );

    try {
      var response = await http.get(url);
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['result'] != null) {
        var location = jsonResponse['result']['geometry']['location'];
        setState(() {
          _destinationLocation = Position(location['lng'], location['lat']);
          _destinationName = jsonResponse['result']['name'] ?? description;
          _destinationAddress =
              jsonResponse['result']['formatted_address'] ?? "";
          _currentState = MapState.placeDetail;
        });

        _drawMarkers();
        _updateCamera(_destinationLocation!, 15.0);
        _sheetAnimationController.forward();
      }
    } catch (e) {
      debugPrint("Lỗi lấy chi tiết địa điểm: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_destinationLocation == null) return;

    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?origin=${_currentLocation.lat},${_currentLocation.lng}&destination=${_destinationLocation!.lat},${_destinationLocation!.lng}&vehicle=car&api_key=$apiKey',
    );

    try {
      var response = await http.get(url);
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
        var route = jsonResponse['routes'][0]['overview_polyline']['points'];
        final leg = jsonResponse['routes'][0]['legs'][0];

        String durationText;
        double durationValue;
        final durData = leg['duration'];
        if (durData is Map) {
          durationText = durData['text']?.toString() ?? '-- phút';
          durationValue = (durData['value'] as num?)?.toDouble() ?? 0;
        } else if (durData is num) {
          durationValue = durData.toDouble();
          final mins = (durationValue / 60).round();
          durationText = '$mins phút';
        } else {
          durationText = '-- phút';
          durationValue = 0;
        }

        String distanceText;
        double distanceValue;
        final distData = leg['distance'];
        if (distData is Map) {
          distanceText = distData['text']?.toString() ?? 'Đang tính...';
          distanceValue = (distData['value'] as num?)?.toDouble() ?? 0;
        } else if (distData is num) {
          distanceValue = distData.toDouble();
          distanceText = '${(distanceValue / 1000).toStringAsFixed(1)} km';
        } else {
          distanceText = 'Đang tính...';
          distanceValue = 0;
        }

        setState(() {
          _duration = durationText;
          _distance = distanceText;
        });

        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(route);
        List<List<double>> coordinates = result
            .map((point) => [point.longitude, point.latitude])
            .toList();

        final navController = context.read<NavigationController>();
        List<NavigationStep> navSteps = [];
        final stepsJson =
            jsonResponse['routes'][0]['legs'][0]['steps'] as List<dynamic>? ??
            [];
        for (final stepJson in stepsJson) {
          final step = stepJson as Map<String, dynamic>;

          String maneuverType = 'depart';
          String? maneuverModifier;
          final maneuverData = step['maneuver'];
          if (maneuverData is Map<String, dynamic>) {
            maneuverType = maneuverData['type']?.toString() ?? 'depart';
            maneuverModifier = maneuverData['modifier']?.toString();
          } else if (maneuverData is String) {
            maneuverType = maneuverData;
          }

          final startLoc = step['start_location'];
          double startLat = 0, startLng = 0;
          if (startLoc is Map<String, dynamic>) {
            startLat = startLoc['lat']?.toDouble() ?? 0;
            startLng = startLoc['lng']?.toDouble() ?? 0;
          }

          final endLoc = step['end_location'];
          double endLat = 0, endLng = 0;
          if (endLoc is Map<String, dynamic>) {
            endLat = endLoc['lat']?.toDouble() ?? 0;
            endLng = endLoc['lng']?.toDouble() ?? 0;
          }

          double stepDist = 0;
          final distData = step['distance'];
          if (distData is Map) {
            stepDist = (distData['value'] as num?)?.toDouble() ?? 0;
          } else if (distData is num) {
            stepDist = distData.toDouble();
          }

          double stepDur = 0;
          final durData = step['duration'];
          if (durData is Map) {
            stepDur = (durData['value'] as num?)?.toDouble() ?? 0;
          } else if (durData is num) {
            stepDur = durData.toDouble();
          }

          String instruction =
              step['html_instructions']?.toString() ??
              step['html_instruction']?.toString() ??
              step['instruction']?.toString() ??
              '';

          navSteps.add(
            NavigationStep(
              instruction: instruction,
              distance: stepDist,
              duration: stepDur,
              maneuverType: _parseManeuverType(maneuverType),
              maneuverModifier: maneuverModifier,
              startLatitude: startLat,
              startLongitude: startLng,
              endLatitude: endLat,
              endLongitude: endLng,
              name: step['name']?.toString(),
            ),
          );
        }

        navController.startNavigation(
          NavigationRoute(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            totalDistance: distanceValue,
            totalDuration: durationValue,
            distanceText: distanceText,
            durationText: durationText,
            steps: navSteps,
            polyline: coordinates,
            originLatitude: _currentLocation.lat.toDouble(),
            originLongitude: _currentLocation.lng.toDouble(),
            destinationLatitude: _destinationLocation!.lat.toDouble(),
            destinationLongitude: _destinationLocation!.lng.toDouble(),
            destinationName: _destinationName,
          ),
        );

        String geojson =
            '''{
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": $coordinates
              }
            }
          ]
        }''';

        _routeGeoJson = geojson;
        _isRouteActive = true;

        await _drawRouteLine();

        _mapboxMap?.setCamera(
          CameraOptions(
            center: Point(coordinates: _currentLocation).toJson(),
            zoom: 14.0,
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi lấy đường đi: $e");
    }
  }

  Future<void> _clearRoute() async {
    _routeGeoJson = null;
    _isRouteActive = false;
    try {
      await _mapboxMap?.style.removeStyleLayer("route_layer");
      await _mapboxMap?.style.removeStyleSource("route_source");
    } catch (e) {}
  }

  static ManeuverType _parseManeuverType(String type) {
    switch (type) {
      case 'depart':
        return ManeuverType.depart;
      case 'arrive':
        return ManeuverType.arrive;
      case 'turn':
        return ManeuverType.turn;
      case 'fork':
        return ManeuverType.fork;
      case 'roundabout':
        return ManeuverType.roundabout;
      case 'merge':
        return ManeuverType.merge;
      case 'on ramp':
      case 'on_ramp':
        return ManeuverType.onRamp;
      case 'off ramp':
      case 'off_ramp':
        return ManeuverType.offRamp;
      case 'ferry':
        return ManeuverType.ferry;
      case 'continue':
        return ManeuverType.continueStraight;
      case 'end of road':
      case 'end_of_road':
        return ManeuverType.endOfRoad;
      case 'new name':
      case 'new_name':
        return ManeuverType.newName;
      case 'notification':
        return ManeuverType.notification;
      default:
        return ManeuverType.continueStraight;
    }
  }

  void _startNavigation() {
    HapticFeedback.heavyImpact();
    _sheetAnimationController.reverse();

    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _currentState = MapState.navigating;
      });
    });

    _fetchAndDrawRoute();

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: _currentLocation).toJson(),
        zoom: 17.0,
        pitch: 45.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  void _startNavigationVision() {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      PageTransition(
        child: const NavigationVisionPage(),
        type: PageTransitionType.slideUp,
      ),
    );
  }

  void _navigateToVision() {
    if (_currentState == MapState.navigating) {
      Navigator.push(
        context,
        PageTransition(
          child: const NavigationVisionPage(),
          type: PageTransitionType.slideUp,
        ),
      );
    } else {
      Navigator.push(
        context,
        PageTransition(
          child: const FlowScreenV2(),
          type: PageTransitionType.slideUp,
        ),
      );
    }
  }

  void _resetToExplore() {
    HapticFeedback.lightImpact();
    _sheetAnimationController.reverse();

    final navController = context.read<NavigationController>();
    navController.stopNavigation();

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _currentState = MapState.explore;
        _destinationLocation = null;
        _searchController.clear();
        _searchResults.clear();
      });
    });

    _clearRoute();
    _drawMarkers();

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: _currentLocation).toJson(),
        zoom: 16.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onNavigateToVision: _navigateToVision,
        onNavigateToSatellite: () {
          Navigator.push(
            context,
            PageTransition(
              child: const SatelliteScreenV2(),
              type: PageTransitionType.fadeSlide,
              duration: const Duration(milliseconds: 600),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            resourceOptions: ResourceOptions(accessToken: mapboxToken),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onTapListener: (coordinate) {
              if (_currentState == MapState.placeDetail) {
                _resetToExplore();
              }
              FocusScope.of(context).unfocus();
            },
          ),
          if (_currentState == MapState.explore ||
              _currentState == MapState.placeDetail)
            _buildModernSearchBar(),
          if (_currentState == MapState.navigating)
            _buildModernNavigationTopBar(),
          if (_currentState == MapState.placeDetail) _buildModernPlaceSheet(),
          if (_currentState == MapState.navigating)
            _buildModernNavigationPanel(),
        ],
      ),
      floatingActionButton: _currentState != MapState.navigating
          ? _buildModernFABs()
          : null,
    );
  }

  Widget _buildModernSearchBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppTheme.backgroundDark.withOpacity(0.95),
                        AppTheme.backgroundDark.withOpacity(0.7),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withOpacity(0.98),
                        Colors.white.withOpacity(0.85),
                        Colors.white.withOpacity(0.4),
                        Colors.transparent,
                      ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              28,
            ),
            child: Column(
              children: [
                _buildSearchInput(themeProvider),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSearchResults(themeProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchInput(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : AppTheme.textDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppTheme.primaryColor.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryColor.withOpacity(0.06)
                : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          if (isDark)
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                if (_currentState == MapState.explore)
                  _buildSearchIconButton(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: Icons.menu_rounded,
                    isDark: isDark,
                  ),
                if (_currentState == MapState.explore) const SizedBox(width: 8),
                if (_currentState == MapState.placeDetail)
                  _buildSearchIconButton(
                    onTap: _resetToExplore,
                    icon: Icons.arrow_back_ios_new_rounded,
                    isDark: isDark,
                  )
                else if (_currentState == MapState.explore)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: "Tìm kiếm điểm đến...",
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black.withOpacity(0.35),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isSearching)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark
                            ? AppTheme.secondaryColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  )
                else if (_searchController.text.isNotEmpty)
                  _buildSearchIconButton(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                      _resetToExplore();
                    },
                    icon: Icons.close_rounded,
                    isDark: isDark,
                    size: 16,
                  ),
                const SizedBox(width: 6),
                _buildProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIconButton({
    required VoidCallback onTap,
    required IconData icon,
    required bool isDark,
    double size = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : AppTheme.primaryColor.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : AppTheme.primaryColor,
          size: size,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              PageTransition(
                child: const TripManagerScreen(),
                type: PageTransitionType.slideLeft,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(
                    0.3 * _pulseAnimation.value,
                  ),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(-1, 1),
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 17,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 19),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.black.withOpacity(0.5);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.cardDark.withOpacity(0.9)
              : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : AppTheme.primaryColor.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 56,
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.05),
              ),
              itemBuilder: (context, index) {
                var place = _searchResults[index];
                String mainText =
                    place['structured_formatting']?['main_text'] ??
                    place['description'] ??
                    "";
                String secondaryText =
                    place['structured_formatting']?['secondary_text'] ?? "";
                int delay = (index * 40).clamp(0, 250);

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 250 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(15 * (1 - value), 0),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _selectPlace(place['place_id'], place['description']),
                      splashColor: AppTheme.primaryColor.withOpacity(0.08),
                      highlightColor: AppTheme.primaryColor.withOpacity(0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          AppTheme.primaryColor.withOpacity(
                                            0.15,
                                          ),
                                          AppTheme.secondaryColor.withOpacity(
                                            0.1,
                                          ),
                                        ]
                                      : [
                                          AppTheme.primaryColor.withOpacity(
                                            0.12,
                                          ),
                                          AppTheme.secondaryColor.withOpacity(
                                            0.06,
                                          ),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.primaryColor.withOpacity(0.12)
                                      : AppTheme.primaryColor.withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(
                                      isDark ? 0.1 : 0.08,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ShaderMask(
                                shaderCallback: (bounds) => AppTheme
                                    .primaryGradient
                                    .createShader(bounds),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: isDark ? 18 : 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mainText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isDark ? 15 : 14,
                                      color: textColor,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (secondaryText.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      secondaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : AppTheme.primaryColor.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : AppTheme.primaryColor.withOpacity(0.4),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPlaceSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _sheetSlideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.cardDark.withOpacity(0.98),
                AppTheme.surfaceDark.withOpacity(0.96),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.12),
                blurRadius: 50,
                offset: const Offset(0, -15),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.accentColor.withOpacity(0.22),
                                AppTheme.accentColor.withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(-2, -2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppTheme.accentColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _destinationName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _destinationAddress,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientButton(
                            text: "Bắt đầu",
                            icon: Icons.navigation_rounded,
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            ),
                            onTap: _startNavigation,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOutlineButton(
                            text: "Xem đường",
                            icon: Icons.route_rounded,
                            onTap: _fetchAndDrawRoute,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.secondaryColor.withOpacity(0.45),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.secondaryColor.withOpacity(0.06),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.secondaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavigationTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundDark.withOpacity(0.97),
              AppTheme.backgroundDark.withOpacity(0.65),
              Colors.transparent,
            ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 10,
          16,
          28,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.cardDark.withOpacity(0.98),
                AppTheme.surfaceDark.withOpacity(0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.successColor.withOpacity(0.22),
                      AppTheme.successColor.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.turn_right_rounded,
                  color: AppTheme.successColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Đang hướng tới",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _destinationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavigationPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: FloatingActionButton.extended(
                        heroTag: "vision_btn",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          if (_currentState == MapState.navigating) {
                            _startNavigationVision();
                          } else {
                            Navigator.push(
                              context,
                              PageTransition(
                                child: const FlowScreenV2(),
                                type: PageTransitionType.slideUp,
                              ),
                            );
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        label: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.accentGradient.createShader(bounds),
                          child: const Text(
                            "GNSS-Vision",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.cardDark.withOpacity(0.98),
                  AppTheme.surfaceDark.withOpacity(0.97),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.successColor.withOpacity(0.2),
                              AppTheme.successColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.successColor.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: AppTheme.successColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _duration,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.successColor,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.successColor,
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "Khoảng cách: $_distance",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _resetToExplore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.accentColor.withOpacity(0.16),
                                AppTheme.accentColor.withOpacity(0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Thoát",
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFABs() {
    return AnimatedBuilder(
      animation: _fabScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabScaleAnimation.value,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: _currentState == MapState.placeDetail ? 260.0 : 0.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.warningColor.withOpacity(
                              0.35 * _pulseAnimation.value,
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_satellite",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            PageTransition(
                              child: const SatelliteScreenV2(),
                              type: PageTransitionType.fadeSlide,
                              duration: const Duration(milliseconds: 600),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.warningColor.withOpacity(0.3),
                                AppTheme.accentColor.withOpacity(0.2),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.satellite_alt_rounded,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryColor.withOpacity(
                              0.35 * (2 - _pulseAnimation.value),
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_location",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (_isLocationLoaded) {
                            _updateCamera(_currentLocation, 16.0);
                          } else {
                            _getUserLocation();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.3),
                                AppTheme.secondaryColor.withOpacity(0.25),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
