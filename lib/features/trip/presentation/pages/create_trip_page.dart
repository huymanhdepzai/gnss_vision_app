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

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getUserLocation();
  }

  void _initAnimations() {
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
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
      setState(() {
        _currentLocation = Position(position.longitude, position.latitude);
        _isLocationLoaded = true;
      });

      if (_mapboxMap != null) {
        _updateCamera(_currentLocation, 14.0);
      }
    } catch (e) {
      debugPrint("Lỗi lấy vị trí: $e");
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
      _updateCamera(_currentLocation, 14.0);
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

  void _handleMapTap(ScreenCoordinate coordinate) {
    if (_selectionMode == SelectionMode.none) return;

    final position = Position(coordinate.x, coordinate.y);

    setState(() {
      if (_selectionMode == SelectionMode.start) {
        _startLocation = position;
        _selectionMode = SelectionMode.none;
      } else if (_selectionMode == SelectionMode.end) {
        _endLocation = position;
        _selectionMode = SelectionMode.none;
      }
    });

    _drawMarkers();
    _updateCamera(position, 15.0);
    _fetchRouteInfo();
  }

  Future<void> _drawMarkers() async {
    if (_circleAnnotationManager == null) return;

    await _circleAnnotationManager?.deleteAll();

    if (_startLocation != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _startLocation!).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 14.0,
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
          circleRadius: 14.0,
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
        setState(() {
          _duration = jsonResponse['routes'][0]['legs'][0]['duration']['text'];
          _distance = jsonResponse['routes'][0]['legs'][0]['distance']['text'];
        });
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
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
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
    } catch (e) {
      debugPrint("Lỗi lấy chi tiết địa điểm: $e");
    } finally {
      setState(() => _isSearching = false);
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
  }

  bool get _canCreateTrip {
    return _titleController.text.isNotEmpty &&
        _startLocation != null &&
        _endLocation != null;
  }

  Future<void> _createTrip() async {
    if (!_canCreateTrip) return;

    HapticFeedback.heavyImpact();

    final tripController = context.read<TripController>();

    double distanceValue = 0;
    if (_distance.isNotEmpty) {
      distanceValue =
          double.tryParse(
            _distance.replaceAll(' km', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    final trip = await tripController.createTrip(
      title: _titleController.text,
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

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _buttonAnimationController.dispose();
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
          backgroundColor: isDark
              ? AppTheme.backgroundDark
              : AppTheme.backgroundLight,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool isDark) {
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
                    AppTheme.backgroundDark.withOpacity(0.8),
                    Colors.transparent,
                  ]
                : [
                    Colors.white.withOpacity(0.98),
                    Colors.white.withOpacity(0.9),
                    Colors.transparent,
                  ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 8,
          16,
          20,
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : AppTheme.textDark,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tạo Lịch Trình Mới',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectionMode != SelectionMode.none
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    enabled: _selectionMode != SelectionMode.none,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textDark,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: _selectionMode == SelectionMode.start
                          ? 'Tìm điểm bắt đầu...'
                          : _selectionMode == SelectionMode.end
                          ? 'Tìm điểm kết thúc...'
                          : 'Nhấn bên dưới để chọn điểm...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: isDark ? Colors.white38 : Colors.black38,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : _isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : null,
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

  Widget _buildSearchResults(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 140,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.cardDark.withOpacity(0.98)
              : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.15),
            ),
            itemBuilder: (context, index) {
              var place = _searchResults[index];
              String mainText =
                  place['structured_formatting']?['main_text'] ??
                  place['description'] ??
                  "";
              String secondaryText =
                  place['structured_formatting']?['secondary_text'] ?? "";

              return Material(
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              if (secondaryText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  secondaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.3),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.cardDark.withOpacity(0.98),
                    AppTheme.surfaceDark.withOpacity(0.98),
                  ]
                : [
                    Colors.white.withOpacity(0.98),
                    AppTheme.cardLight.withOpacity(0.98),
                  ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.1),
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
                  const SizedBox(height: 20),
                  _buildTitleInput(isDark),
                  const SizedBox(height: 16),
                  _buildLocationButtons(isDark),
                  if (_startLocation != null && _endLocation != null) ...[
                    const SizedBox(height: 16),
                    _buildTripInfo(isDark),
                  ],
                  const SizedBox(height: 20),
                  _buildCreateButton(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: _titleController,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textDark,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          fillColor: Colors.transparent,
          hintText: 'Tên lịch trình (ví dụ: Chuyến đi Đà Lạt)',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 15,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.secondaryColor.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildLocationButtons(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLocationButton(
                icon: Icons.circle_rounded,
                iconColor: AppTheme.primaryColor,
                label: 'Điểm bắt đầu',
                value: _startAddress.isNotEmpty
                    ? _startAddress
                    : _startLocation != null
                    ? '${_startLocation!.lat.toStringAsFixed(4)}, ${_startLocation!.lng.toStringAsFixed(4)}'
                    : 'Chưa chọn',
                isSelected: _selectionMode == SelectionMode.start,
                hasValue: _startLocation != null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _selectionMode = SelectionMode.start;
                  });
                },
                onLongPress: _isLocationLoaded
                    ? _useCurrentLocationAsStart
                    : null,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLocationButton(
                icon: Icons.location_on_rounded,
                iconColor: AppTheme.accentColor,
                label: 'Điểm kết thúc',
                value: _endAddress.isNotEmpty
                    ? _endAddress
                    : _endLocation != null
                    ? '${_endLocation!.lat.toStringAsFixed(4)}, ${_endLocation!.lng.toStringAsFixed(4)}'
                    : 'Chưa chọn',
                isSelected: _selectionMode == SelectionMode.end,
                hasValue: _endLocation != null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _selectionMode = SelectionMode.end;
                  });
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
        if (_selectionMode != SelectionMode.none)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap vào bản đồ hoặc tìm kiếm địa điểm ở trên',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isSelected,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              iconColor.withOpacity(isSelected ? 0.25 : 0.15),
              iconColor.withOpacity(isSelected ? 0.1 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withOpacity(isSelected ? 0.5 : 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasValue)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // if (onLongPress != null) ...[
            //   const SizedBox(height: 4),
            //   Text(
            //     'Giữ để dùng vị trí hiện tại',
            //     style: TextStyle(
            //       color: isDark ? Colors.white38 : Colors.black38,
            //       fontSize: 10,
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Icons.straighten_rounded,
            label: 'Khoảng cách',
            value: _distance.isNotEmpty ? _distance : '-- km',
            color: AppTheme.accentColor,
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
          ),
          _buildInfoItem(
            icon: Icons.timer_outlined,
            label: 'Thời gian ước tính',
            value: _duration.isNotEmpty ? _duration : '-- phút',
            color: AppTheme.successColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCreateButton(bool isDark) {
    final canCreate = _canCreateTrip;

    return GestureDetector(
      onTap: canCreate ? _createTrip : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: canCreate
              ? AppTheme.primaryGradient
              : LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.3),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: canCreate
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Tạo Lịch Trình',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
