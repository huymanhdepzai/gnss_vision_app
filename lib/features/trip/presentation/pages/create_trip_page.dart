import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../controllers/trip_controller.dart';

enum SelectionMode { start, end, none }

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({Key? key}) : super(key: key);

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  final TextEditingController _titleController = TextEditingController();

  bool _isFormExpanded = true;
  bool _is3DMode = false;
  SelectionMode _selectionMode = SelectionMode.none;
  String _startAddress = '';
  String _endAddress = '';

  Position? _startLocation;
  Position? _endLocation;
  late Position _currentLocation;
  bool _isLocationLoaded = false;
  StreamSubscription<geo.Position>? _positionStream;

  String _distance = '';
  String _duration = '';

  late AnimationController _panelAnimationController;
  late Animation<double> _panelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getUserLocation();
  }

  void _initAnimations() {
    _panelAnimationController = AnimationController(
      vsync: this,
      duration: UIConsts.animEntrance,
    );
    _panelSlideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _panelAnimationController,
        curve: UIConsts.curveEntrance,
      ),
    );
    _panelAnimationController.forward();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }

    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = Position(position.longitude, position.latitude);
          _isLocationLoaded = true;
        });

        if (_mapboxMap != null) {
          _updateCamera(_currentLocation, 14.0);
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy vị trí: $e");
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _updateMapStyle();
  }

  void _updateMapStyle() {
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final style = isDark ? 'navigation_night' : 'navigation_day';

    _mapboxMap?.loadStyleURI(
      'https://tiles.goong.io/assets/$style.json?api_key=$mapTilesKey',
    );
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager = await _mapboxMap?.annotations
        .createCircleAnnotationManager();
    _polylineAnnotationManager = await _mapboxMap?.annotations
        .createPolylineAnnotationManager();

    if (_isLocationLoaded) {
      _updateCamera(_currentLocation, 14.0);
    }
    
    if (_startLocation != null || _endLocation != null) {
      _drawMarkers();
    }
  }

  void _updateCamera(Position position, double zoom) {
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: position).toJson(),
        zoom: zoom,
        pitch: _is3DMode ? 60.0 : 0.0,
      ),
    );
  }

  void _toggleMapMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });
    _mapboxMap?.setCamera(
      CameraOptions(
        pitch: _is3DMode ? 60.0 : 0.0,
        bearing: _is3DMode ? 45.0 : 0.0,
      ),
    );
    HapticFeedback.lightImpact();
  }

  void _handleMapTap(ScreenCoordinate coordinate) async {
    if (_selectionMode == SelectionMode.none || _mapboxMap == null) return;

    final pointMap = await _mapboxMap!.coordinateForPixel(coordinate);
    if (pointMap == null || pointMap['coordinates'] == null) return;

    final coords = pointMap['coordinates'] as List<dynamic>;
    if (coords.length < 2) return;
    
    final position = Position(coords[0] as num, coords[1] as num);

    setState(() {
      if (_selectionMode == SelectionMode.start) {
        _startLocation = position;
        _startAddress = '${position.lat.toStringAsFixed(4)}, ${position.lng.toStringAsFixed(4)}';
        _selectionMode = SelectionMode.none;
      } else if (_selectionMode == SelectionMode.end) {
        _endLocation = position;
        _endAddress = '${position.lat.toStringAsFixed(4)}, ${position.lng.toStringAsFixed(4)}';
        _selectionMode = SelectionMode.none;
      }
    });

    _drawMarkers();
    _updateCamera(position, 15.0);
    _fetchRouteInfo();
    HapticFeedback.lightImpact();
  }

  Future<void> _drawMarkers() async {
    if (_circleAnnotationManager == null) return;

    await _circleAnnotationManager?.deleteAll();

    if (_startLocation != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _startLocation!).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    if (_endLocation != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _endLocation!).toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }
  }

  Future<void> _fetchRouteInfo() async {
    if (_startLocation == null || _endLocation == null) return;

    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?origin=${_startLocation!.lat},${_startLocation!.lng}&destination=${_endLocation!.lat},${_endLocation!.lng}&vehicle=car&api_key=$apiKey',
    );

    try {
      var response = await http.get(url);
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
        if (mounted) {
          setState(() {
            _duration = jsonResponse['routes'][0]['legs'][0]['duration']['text'];
            _distance = jsonResponse['routes'][0]['legs'][0]['distance']['text'];
          });
        }
        
        final overviewPolyline = jsonResponse['routes'][0]['overview_polyline']['points'];
        if (overviewPolyline != null) {
          _drawRoute(overviewPolyline);
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông tin đường: $e");
    }
  }

  Future<void> _drawRoute(String encodedPolyline) async {
    if (_polylineAnnotationManager == null) return;
    
    await _polylineAnnotationManager?.deleteAll();
    
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
    
    List<Position> coordinates = decodedPoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    if (coordinates.isNotEmpty) {
      await _polylineAnnotationManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates).toJson(),
          lineColor: AppTheme.primaryColor.value,
          lineWidth: 5.0,
        ),
      );
      
      if (_startLocation != null && _endLocation != null) {
         double lat1 = _startLocation!.lat.toDouble();
         double lng1 = _startLocation!.lng.toDouble();
         double lat2 = _endLocation!.lat.toDouble();
         double lng2 = _endLocation!.lng.toDouble();
         
         double centerLat = (lat1 + lat2) / 2;
         double centerLng = (lng1 + lng2) / 2;
         
         double latDiff = (lat1 - lat2).abs();
         double lngDiff = (lng1 - lng2).abs();
         double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
         
         double zoom = 14.0;
         if (maxDiff > 0.1) zoom = 10.0;
         if (maxDiff > 0.5) zoom = 8.0;
         if (maxDiff > 1.0) zoom = 6.0;

         _updateCamera(Position(centerLng, centerLat), zoom);
      }
    }
  }

  void _openSearchSheet(bool isStart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSearchSheet(
        isStart: isStart,
        isLocationLoaded: _isLocationLoaded,
        currentLocation: _currentLocation,
        onPlaceSelected: (position, address) {
          Navigator.pop(context);
          setState(() {
            if (isStart) {
              _startLocation = position;
              _startAddress = address;
              _selectionMode = SelectionMode.none;
            } else {
              _endLocation = position;
              _endAddress = address;
              _selectionMode = SelectionMode.none;
            }
          });
          _drawMarkers();
          _updateCamera(position, 15.0);
          _fetchRouteInfo();
        },
        onSelectOnMap: () {
          Navigator.pop(context);
          setState(() {
            _selectionMode = isStart ? SelectionMode.start : SelectionMode.end;
          });
        },
      ),
    );
  }

  Future<void> _useCurrentLocationAsStart() async {
    if (!_isLocationLoaded) return;

    setState(() {
      _startLocation = _currentLocation;
      _startAddress = 'Vị trí hiện tại';
      _selectionMode = SelectionMode.none;
    });

    _drawMarkers();
    _fetchRouteInfo();
    HapticFeedback.mediumImpact();
  }

  bool get _canCreateTrip {
    return _titleController.text.isNotEmpty &&
        _startLocation != null &&
        _endLocation != null;
  }

  Future<void> _createTrip() async {
    if (!_canCreateTrip) return;

    final tripController = context.read<TripController>();
    final title = _titleController.text.trim();

    if (!tripController.isTripTitleAvailable(title)) {
      _showTopNotification(
        'Tên hành trình đã tồn tại. Vui lòng chọn tên khác.',
        AppTheme.errorDark,
      );
      return;
    }

    HapticFeedback.heavyImpact();

    double distanceValue = 0;
    if (_distance.isNotEmpty) {
      distanceValue =
          double.tryParse(
            _distance.replaceAll(' km', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    final trip = await tripController.createTrip(
      title: title,
      startLat: _startLocation!.lat.toDouble(),
      startLng: _startLocation!.lng.toDouble(),
      endLat: _endLocation!.lat.toDouble(),
      endLng: _endLocation!.lng.toDouble(),
      startAddress: _startAddress,
      endAddress: _endAddress,
      distance: distanceValue,
      duration: _duration,
    );

    if (trip != null && mounted) {
      Navigator.pop(context, trip);
    }
  }

  void _showTopNotification(String message, Color backgroundColor) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(
                  opacity: (value + 100) / 100,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _panelAnimationController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.adaptiveSurface(isDark),
      resizeToAvoidBottomInset: false,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            if (mapboxToken.isNotEmpty)
              MapWidget(
                key: const ValueKey("mapWidget"),
                resourceOptions: ResourceOptions(accessToken: mapboxToken),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onTapListener: _handleMapTap,
                styleUri: 'mapbox://styles/mapbox/navigation-day-v1',
                cameraOptions: CameraOptions(
                  center: Point(
                    coordinates: Position(105.8342, 21.0278),
                  ).toJson(),
                  zoom: 12.0,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_rounded,
                      size: 64,
                      color: AppTheme.adaptiveSubtext(isDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bản đồ không khả dụng',
                      style: TextStyle(
                        color: AppTheme.adaptiveText(isDark),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            _buildTopBar(isDark),
            _buildBottomPanel(isDark),
            if (_selectionMode != SelectionMode.none)
              _buildSelectionIndicator(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: EntranceAnimation(
        type: EntranceType.fadeSlideUp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: AppTheme.glassDecoration(
            isDark: isDark,
            tintColor: AppTheme.primaryColor,
          ).copyWith(
            borderRadius: BorderRadius.circular(UIConsts.radiusFull),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseWidget(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _selectionMode == SelectionMode.start
                      ? 'Chạm vào bản đồ để chọn điểm BẮT ĐẦU'
                      : 'Chạm vào bản đồ để chọn điểm KẾT THÚC',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _selectionMode = SelectionMode.none),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: PressScale(
        onTap: () => Navigator.pop(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.adaptiveText(isDark), size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _panelSlideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 500 * _panelSlideAnimation.value),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingButton(
                    isDark: isDark,
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      if (_isLocationLoaded) {
                        _updateCamera(_currentLocation, 15.0);
                      }
                      HapticFeedback.lightImpact();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFloatingButton(
                    isDark: isDark,
                    icon: _is3DMode ? Icons.layers_clear_rounded : Icons.layers_rounded,
                    onTap: _toggleMapMode,
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              decoration: BoxDecoration(
            color: AppTheme.adaptiveSurface(isDark).withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 40,
                offset: const Offset(0, 15),
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isFormExpanded = !_isFormExpanded),
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity! > 0) {
                          setState(() => _isFormExpanded = false);
                        } else if (details.primaryVelocity! < 0) {
                          setState(() => _isFormExpanded = true);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionLabel(isDark, "THÔNG TIN HÀNH TRÌNH"),
                                Icon(
                                  _isFormExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                  color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.6),
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: _isFormExpanded
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                _buildTitleInput(isDark),
                                const SizedBox(height: 24),
                                _buildSectionLabel(isDark, "ĐIỂM ĐI & ĐIỂM ĐẾN"),
                                const SizedBox(height: 12),
                                _buildLocationSelectors(isDark),
                                if (_startLocation != null && _endLocation != null) ...[
                                  const SizedBox(height: 24),
                                  _buildTripSummary(isDark),
                                ],
                                const SizedBox(height: 24),
                                _buildCreateButton(isDark),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(bool isDark, String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.6),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTitleInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: TextField(
        controller: _titleController,
        style: TextStyle(
          color: AppTheme.adaptiveText(isDark),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tên chuyến đi của bạn...',
          hintStyle: TextStyle(
            color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.4),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectors(bool isDark) {
    return Column(
      children: [
        _buildLocationRow(
          icon: Icons.my_location_rounded,
          color: AppTheme.primaryColor,
          label: 'Điểm khởi hành',
          address: _startAddress.isNotEmpty ? _startAddress : 'Chọn điểm khởi hành...',
          isSelected: _selectionMode == SelectionMode.start,
          hasValue: _startLocation != null,
          onTap: () => _openSearchSheet(true),
          onLongPress: _isLocationLoaded ? _useCurrentLocationAsStart : null,
          isDark: isDark,
        ),
        Container(
          margin: const EdgeInsets.only(left: 20),
          height: 24,
          width: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.5),
                AppTheme.accentColor.withOpacity(0.5),
              ],
            ),
          ),
        ),
        _buildLocationRow(
          icon: Icons.location_on_rounded,
          color: AppTheme.accentColor,
          label: 'Điểm đến',
          address: _endAddress.isNotEmpty ? _endAddress : 'Chọn điểm đến...',
          isSelected: _selectionMode == SelectionMode.end,
          hasValue: _endLocation != null,
          onTap: () => _openSearchSheet(false),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
    required bool isSelected,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required bool isDark,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.08)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      color: hasValue ? AppTheme.adaptiveText(isDark) : AppTheme.adaptiveSubtext(isDark).withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasValue)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 12),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _buildTripSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.route_rounded,
            value: _distance.isNotEmpty ? _distance : '--',
            label: 'KHOẢNG CÁCH',
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 30,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
          _buildSummaryItem(
            icon: Icons.timer_rounded,
            value: _duration.isNotEmpty ? _duration : '--',
            label: 'THỜI GIAN DỰ KIẾN',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.secondaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.adaptiveText(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.secondaryColor.withOpacity(0.7),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(bool isDark) {
    final canCreate = _canCreateTrip;

    return ModernButton(
      text: 'XÁC NHẬN LÊN LỊCH',
      onPressed: canCreate ? _createTrip : null,
      icon: Icons.check_circle_outline_rounded,
      color: AppTheme.primaryColor,
      borderRadius: UIConsts.radiusXL,
    );
  }
}

class LocationSearchSheet extends StatefulWidget {
  final bool isStart;
  final bool isLocationLoaded;
  final Position? currentLocation;
  final Function(Position, String) onPlaceSelected;
  final VoidCallback onSelectOnMap;

  const LocationSearchSheet({
    Key? key,
    required this.isStart,
    required this.isLocationLoaded,
    this.currentLocation,
    required this.onPlaceSelected,
    required this.onSelectOnMap,
  }) : super(key: key);

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchPlaces(query);
      } else {
        if (mounted) setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (mounted) setState(() => _isSearching = true);
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final location = widget.isLocationLoaded && widget.currentLocation != null
        ? '${widget.currentLocation!.lat},${widget.currentLocation!.lng}'
        : '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/AutoComplete?api_key=$apiKey&input=${Uri.encodeComponent(query)}${location.isNotEmpty ? '&location=$location&radius=50' : ''}',
    );

    try {
      var response = await http.get(url);
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['predictions'] != null) {
        if (mounted) {
          setState(() {
            _searchResults = jsonResponse['predictions'];
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tìm kiếm: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _isSearching = true);

    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/Detail?place_id=$placeId&api_key=$apiKey',
    );

    try {
      var response = await http.get(url);
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['result'] != null) {
        var location = jsonResponse['result']['geometry']['location'];
        final position = Position(location['lng'], location['lat']);
        final name = jsonResponse['result']['name'] ?? description;

        widget.onPlaceSelected(position, name);
      }
    } catch (e) {
      debugPrint("Lỗi lấy chi tiết địa điểm: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppTheme.adaptiveSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppTheme.adaptiveText(isDark)),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.isStart ? 'Chọn điểm khởi hành' : 'Chọn điểm đến',
                  style: TextStyle(
                    color: AppTheme.adaptiveText(isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: TextStyle(color: AppTheme.adaptiveText(isDark)),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm địa điểm...',
                hintStyle: TextStyle(color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                suffixIcon: _isSearching
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_searchResults.isEmpty) ...[
            if (widget.isLocationLoaded)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.my_location_rounded, color: AppTheme.primaryColor, size: 20),
                ),
                title: Text('Chọn vị trí hiện tại', style: TextStyle(color: AppTheme.adaptiveText(isDark), fontWeight: FontWeight.bold)),
                onTap: () {
                  widget.onPlaceSelected(widget.currentLocation!, 'Vị trí hiện tại');
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.map_rounded, color: AppTheme.accentColor, size: 20),
              ),
              title: Text('Chọn trên bản đồ', style: TextStyle(color: AppTheme.adaptiveText(isDark), fontWeight: FontWeight.bold)),
              onTap: widget.onSelectOnMap,
            ),
          ],
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => ModernDivider(isDark: isDark, indent: 64),
                itemBuilder: (context, index) {
                  var place = _searchResults[index];
                  String mainText = place['structured_formatting']?['main_text'] ?? place['description'] ?? "";
                  String secondaryText = place['structured_formatting']?['secondary_text'] ?? "";
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: ModernIconContainer(
                      icon: Icons.location_on_rounded,
                      color: AppTheme.primaryColor,
                      size: 40,
                      iconSize: 18,
                    ),
                    title: Text(mainText, style: TextStyle(color: AppTheme.adaptiveText(isDark), fontWeight: FontWeight.w700)),
                    subtitle: Text(secondaryText, style: TextStyle(color: AppTheme.adaptiveSubtext(isDark))),
                    onTap: () => _selectPlace(place['place_id'], place['description']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
