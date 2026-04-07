import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';

import '../core/app_theme.dart';
import '../core/page_transitions.dart';
import 'satellite_screen_v2.dart';
import 'flow_screen_v2.dart';

enum MapState { explore, placeDetail, navigating }

class MapHomeScreenV2 extends StatefulWidget {
  const MapHomeScreenV2({Key? key}) : super(key: key);

  @override
  State<MapHomeScreenV2> createState() => _MapHomeScreenV2State();
}

class _MapHomeScreenV2State extends State<MapHomeScreenV2>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;

  MapState _currentState = MapState.explore;

  Position _currentLocation = Position(105.804817, 21.028511);
  bool _isLocationLoaded = false;

  String _destinationName = "";
  String _destinationAddress = "";
  Position? _destinationLocation;

  String _distance = "Đang tính...";
  String _duration = "-- phút";

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
    _initAnimations();
    _getUserLocation();
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
    )..repeat(reverse: true);

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _fabAnimationController.dispose();
    _sheetAnimationController.dispose();
    _pulseController.dispose();
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

    geo.Position position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = Position(position.longitude, position.latitude);
      _isLocationLoaded = true;
    });

    if (_mapboxMap != null && _circleAnnotationManager != null) {
      _updateCamera(_currentLocation, 16.0);
      _drawMarkers();
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

        setState(() {
          _duration = jsonResponse['routes'][0]['legs'][0]['duration']['text'];
          _distance = jsonResponse['routes'][0]['legs'][0]['distance']['text'];
        });

        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(route);
        List<List<double>> coordinates = result
            .map((point) => [point.longitude, point.latitude])
            .toList();

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

        await _clearRoute();

        await _mapboxMap?.style.addSource(
          GeoJsonSource(id: "route_source", data: geojson),
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
    try {
      await _mapboxMap?.style.removeStyleLayer("route_layer");
      await _mapboxMap?.style.removeStyleSource("route_source");
    } catch (e) {}
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

  void _resetToExplore() {
    HapticFeedback.lightImpact();
    _sheetAnimationController.reverse();

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
      drawer: _buildModernDrawer(),
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

  Widget _buildModernDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Stack(
        children: [
          // Background Glass Effect
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.backgroundDark.withOpacity(0.9),
                        AppTheme.surfaceDark.withOpacity(0.85),
                      ],
                    ),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Drawer Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDrawerHeader(),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "DEMO FUNCTIONS",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDrawerItem(
                  icon: Icons.auto_awesome_rounded,
                  title: "GNSS-Vision (V2)",
                  subtitle: "Sensor fusion & AI Object detection",
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      PageTransition(
                        child: const FlowScreenV2(),
                        type: PageTransitionType.slideUp,
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.satellite_alt_rounded,
                  title: "Satellite View (V2)",
                  subtitle: "Real-time 3D Globe & GNSS Status",
                  color: AppTheme.warningColor,
                  onTap: () {
                    Navigator.pop(context);
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
                const Spacer(),
                _buildDrawerFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            "Navigation AI",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Next-Gen Mobility System",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.2),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white60, size: 18),
          ),
          const SizedBox(width: 16),
          const Text(
            "Settings v2.0",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
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
              AppTheme.backgroundDark.withOpacity(0.7),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 10,
          16,
          20,
        ),
        child: Column(
          children: [
            _buildSearchInput(),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSearchResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (_currentState == MapState.explore)
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                if (_currentState == MapState.explore) const SizedBox(width: 12),
                if (_currentState == MapState.placeDetail)
                  GestureDetector(
                    onTap: _resetToExplore,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          AppTheme.secondaryColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Tìm kiếm điểm đến...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 16,
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
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.secondaryColor,
                      ),
                    ),
                  )
                else if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                      _resetToExplore();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                        size: 16,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(
                              0.4 * _pulseAnimation.value,
                            ),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.transparent,
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.white.withOpacity(0.1)),
              itemBuilder: (context, index) {
                var place = _searchResults[index];
                String mainText =
                    place['structured_formatting']?['main_text'] ??
                    place['description'] ??
                    "";
                String secondaryText =
                    place['structured_formatting']?['secondary_text'] ?? "";
                int delay = (index * 50).clamp(0, 300);

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(30 * (1 - value), 0),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _selectPlace(place['place_id'], place['description']),
                      splashColor: AppTheme.primaryColor.withOpacity(0.1),
                      highlightColor: AppTheme.primaryColor.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor.withOpacity(0.2),
                                    AppTheme.secondaryColor.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.secondaryColor,
                                size: 20,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (secondaryText.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      secondaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.north_west_rounded,
                              color: Colors.white.withOpacity(0.3),
                              size: 18,
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
    return SlideTransition(
      position: _sheetSlideAnimation,
      child: Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.cardDark.withOpacity(0.98),
                AppTheme.surfaceDark.withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.3),
                              AppTheme.secondaryColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentColor.withOpacity(0.2),
                                AppTheme.accentColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppTheme.accentColor,
                            size: 28,
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _destinationAddress,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
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
                        const SizedBox(width: 16),
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
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.secondaryColor.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.secondaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
            colors: [AppTheme.backgroundDark, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 10,
          16,
          20,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.cardDark.withOpacity(0.95),
                AppTheme.surfaceDark.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successColor.withOpacity(0.3),
                      AppTheme.successColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.turn_right_rounded,
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
                      "Đang hướng tới",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _destinationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
            padding: EdgeInsets.only(right: 20, bottom: 16),
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
                        backgroundColor: AppTheme.primaryColor,
                        elevation: 8,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          Navigator.push(
                            context,
                            PageTransition(
                              child: const FlowScreenV2(),
                              type: PageTransitionType.slideUp,
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
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
                  AppTheme.surfaceDark.withOpacity(0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    28,
                    28,
                    MediaQuery.of(context).padding.bottom + 28,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.successColor.withOpacity(0.2),
                              AppTheme.successColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: AppTheme.successColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _duration,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.successColor,
                              ),
                            ),
                            Text(
                              "Khoảng cách: $_distance",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _resetToExplore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            "Thoát",
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
              bottom: _currentState == MapState.placeDetail ? 280.0 : 0.0,
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
                              0.4 * _pulseAnimation.value,
                            ),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_satellite",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 8,
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
                                AppTheme.accentColor.withOpacity(0.3),
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
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryColor.withOpacity(
                              0.4 * (2 - _pulseAnimation.value),
                            ),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_location",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 8,
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
                                AppTheme.secondaryColor.withOpacity(0.3),
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
