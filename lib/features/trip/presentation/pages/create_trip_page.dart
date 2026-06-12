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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

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
      ),
    );
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
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông tin đường: $e");
    }
  }

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
    final location = _isLocationLoaded
        ? '${_currentLocation.lat},${_currentLocation.lng}'
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
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchController.clear();
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
        final position = Position(location['lng'], location['lat']);
        final name = jsonResponse['result']['name'] ?? description;

        if (mounted) {
          setState(() {
            if (_selectionMode == SelectionMode.start) {
              _startLocation = position;
              _startAddress = name;
              _selectionMode = SelectionMode.none;
            } else if (_selectionMode == SelectionMode.end) {
              _endLocation = position;
              _endAddress = name;
              _selectionMode = SelectionMode.none;
            }
          });

          _drawMarkers();
          _updateCamera(position, 15.0);
          _fetchRouteInfo();
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy chi tiết địa điểm: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
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
    _searchController.dispose();
    _debounce?.cancel();
    _panelAnimationController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: AppTheme.adaptiveBackground(isDark),
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              MapWidget(
                key: const ValueKey("createTripMapWidget"),
                resourceOptions: ResourceOptions(accessToken: mapboxToken),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onTapListener: (coordinate) {
                  if (_selectionMode != SelectionMode.none) {
                    _handleMapTap(coordinate);
                  }
                },
              ),
              _buildTopBar(isDark),
              if (_searchResults.isNotEmpty || _isSearching)
                _buildSearchResults(isDark),
              _buildBottomPanel(isDark),
              if (_selectionMode != SelectionMode.none)
                _buildSelectionIndicator(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionIndicator(bool isDark) {
    return Positioned(
      bottom: 420, 
      left: UIConsts.spacingXL,
      right: UIConsts.spacingXL,
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
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          UIConsts.spacingLG,
          MediaQuery.of(context).padding.top + 8,
          UIConsts.spacingLG,
          UIConsts.spacing3XL,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.adaptiveBackground(isDark).withOpacity(0.9),
              AppTheme.adaptiveBackground(isDark).withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                PressScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: AppTheme.glassDecoration(isDark: isDark).copyWith(
                      borderRadius: BorderRadius.circular(UIConsts.radiusMD),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.adaptiveText(isDark),
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: UIConsts.spacingLG),
                Expanded(
                  child: Text(
                    'Lên Lịch Trình',
                    style: TextStyle(
                      color: AppTheme.adaptiveText(isDark),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: UIConsts.spacingXL),
            _buildSearchBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return EntranceAnimation(
      delay: const Duration(milliseconds: 200),
      child: Container(
        decoration: AppTheme.glassDecoration(isDark: isDark).copyWith(
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          border: Border.all(
            color: _selectionMode != SelectionMode.none
                ? AppTheme.primaryColor.withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            width: _selectionMode != SelectionMode.none ? 2 : 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: AppTheme.adaptiveText(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: _selectionMode == SelectionMode.start
                ? 'Tìm điểm bắt đầu...'
                : _selectionMode == SelectionMode.end
                ? 'Tìm điểm kết thúc...'
                : 'Tìm kiếm địa điểm...',
            hintStyle: TextStyle(
              color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.4),
              fontSize: 15,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: UIConsts.spacingLG,
              vertical: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _selectionMode != SelectionMode.none 
                  ? AppTheme.primaryColor 
                  : AppTheme.adaptiveSubtext(isDark),
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: AppTheme.adaptiveSubtext(isDark), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  )
                : _isSearching
                ? Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 140,
      left: UIConsts.spacingLG,
      right: UIConsts.spacingLG,
      child: EntranceAnimation(
        type: EntranceType.fadeSlideUp,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: AppTheme.adaptiveSurface(isDark).withOpacity(0.98),
            borderRadius: BorderRadius.circular(UIConsts.radius2XL),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.adaptiveShadow(isDark).withOpacity(isDark ? 0.6 : 0.2),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UIConsts.radius2XL),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearching && _searchResults.isEmpty)
                    _buildSearchLoading(isDark)
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: UIConsts.spacingSM),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => ModernDivider(isDark: isDark, indent: 72),
                        itemBuilder: (context, index) {
                          var place = _searchResults[index];
                          String mainText = place['structured_formatting']?['main_text'] ?? place['description'] ?? "";
                          String secondaryText = place['structured_formatting']?['secondary_text'] ?? "";

                          return ListTile(
                            onTap: () => _selectPlace(place['place_id'], place['description']),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: ModernIconContainer(
                              icon: Icons.location_on_rounded,
                              color: AppTheme.primaryColor,
                              size: 40,
                              iconSize: 18,
                            ),
                            title: Text(
                              mainText,
                              style: TextStyle(
                                color: AppTheme.adaptiveText(isDark),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              secondaryText,
                              style: TextStyle(
                                color: AppTheme.adaptiveSubtext(isDark),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.2),
                              size: 14,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đang tìm kiếm...',
            style: TextStyle(
              color: AppTheme.adaptiveSubtext(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.adaptiveSurface(isDark).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.adaptiveShadow(isDark).withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(isDark),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(isDark, "THÔNG TIN HÀNH TRÌNH"),
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
                        const SizedBox(height: 32),
                        _buildCreateButton(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.adaptiveDivier(isDark).withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionLabel(bool isDark, String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.5),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTitleInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(UIConsts.radiusLG),
        border: Border.all(color: AppTheme.adaptiveDivier(isDark)),
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
            color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.3),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.iconContainerDecoration(
              isDark: isDark,
              color: AppTheme.primaryColor,
            ),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectors(bool isDark) {
    return Column(
      children: [
        _buildLocationRow(
          isStart: true,
          icon: Icons.my_location_rounded,
          color: AppTheme.primaryColor,
          label: 'Điểm bắt đầu',
          address: _startAddress.isNotEmpty ? _startAddress : 'Chọn điểm khởi hành...',
          isSelected: _selectionMode == SelectionMode.start,
          hasValue: _startLocation != null,
          onTap: () => setState(() => _selectionMode = SelectionMode.start),
          onLongPress: _isLocationLoaded ? _useCurrentLocationAsStart : null,
          isDark: isDark,
        ),
        Container(
          margin: const EdgeInsets.only(left: 38),
          height: 20,
          width: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primaryColor.withOpacity(0.5), AppTheme.accentColor.withOpacity(0.5)],
            ),
          ),
        ),
        _buildLocationRow(
          isStart: false,
          icon: Icons.location_on_rounded,
          color: AppTheme.accentColor,
          label: 'Điểm kết thúc',
          address: _endAddress.isNotEmpty ? _endAddress : 'Chọn điểm đến...',
          isSelected: _selectionMode == SelectionMode.end,
          hasValue: _endLocation != null,
          onTap: () => setState(() => _selectionMode = SelectionMode.end),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required bool isStart,
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
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: UIConsts.animNormal,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.08) 
              : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01)),
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          border: Border.all(
            color: isSelected ? color : AppTheme.adaptiveDivier(isDark),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
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
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      color: hasValue ? AppTheme.adaptiveText(isDark) : AppTheme.adaptiveSubtext(isDark).withOpacity(0.5),
                      fontSize: 14,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasValue)
              const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20)
            else
              Icon(Icons.add_location_alt_outlined, color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withOpacity(0.15),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(UIConsts.radiusXL),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            icon: Icons.route_rounded,
            value: _distance.isNotEmpty ? _distance : '-- km',
            label: 'QUÃNG ĐƯỜNG',
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: AppTheme.secondaryColor.withOpacity(0.1),
          ),
          _buildSummaryItem(
            icon: Icons.schedule_rounded,
            value: _duration.isNotEmpty ? _duration : '-- phút',
            label: 'THỜI GIAN',
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
