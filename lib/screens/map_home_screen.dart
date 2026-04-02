import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'flow_screen.dart'; // Import màn hình Vision
import 'satellite_screen.dart'; // 🌟 IMPORT MÀN HÌNH VỆ TINH MỚI TẠO

enum MapState { explore, placeDetail, navigating }

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({Key? key}) : super(key: key);

  @override
  _MapHomeScreenState createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;

  MapState _currentState = MapState.explore;

  // Vị trí mặc định
  Position _currentLocation = Position(105.804817, 21.028511);
  bool _isLocationLoaded = false;

  // Điểm đến THẬT
  String _destinationName = "";
  String _destinationAddress = "";
  Position? _destinationLocation;

  // Thông tin quãng đường
  String _distance = "Đang tính...";
  String _duration = "-- phút";

  // Biến cho thanh tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
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
        desiredAccuracy: geo.LocationAccuracy.high);

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
        'https://tiles.goong.io/assets/navigation_day.json?api_key=$mapTilesKey');
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager =
    await _mapboxMap?.annotations.createCircleAnnotationManager();

    if (_isLocationLoaded) {
      _updateCamera(_currentLocation, 16.0);
      _drawMarkers();
    }
  }

  void _updateCamera(Position position, double zoom) {
    _mapboxMap?.setCamera(CameraOptions(
      center: Point(coordinates: position).toJson(),
      zoom: zoom,
    ));
  }

  Future<void> _drawMarkers() async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager?.deleteAll();

    if (_isLocationLoaded) {
      // User location marker (Outer ring)
      await _circleAnnotationManager?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _currentLocation).toJson(),
        circleColor: Colors.indigo.withOpacity(0.2).value,
        circleRadius: 18.0,
      ));
      // User location marker (Inner solid)
      await _circleAnnotationManager?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _currentLocation).toJson(),
        circleColor: Colors.indigo.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ));
    }

    if (_currentState != MapState.explore && _destinationLocation != null) {
      await _circleAnnotationManager?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _destinationLocation!).toJson(),
        circleColor: Colors.redAccent.value,
        circleRadius: 10.0,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.value,
      ));
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
        'https://rsapi.goong.io/Place/AutoComplete?api_key=$apiKey&input=${Uri.encodeComponent(query)}&location=${_currentLocation.lat},${_currentLocation.lng}&radius=50');

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
    FocusScope.of(context).unfocus(); // Đóng bàn phím
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchController.text = description;
    });

    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse('https://rsapi.goong.io/Place/Detail?place_id=$placeId&api_key=$apiKey');

    try {
      var response = await http.get(url);
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['result'] != null) {
        var location = jsonResponse['result']['geometry']['location'];
        setState(() {
          _destinationLocation = Position(location['lng'], location['lat']);
          _destinationName = jsonResponse['result']['name'] ?? description;
          _destinationAddress = jsonResponse['result']['formatted_address'] ?? "";
          _currentState = MapState.placeDetail;
        });

        _drawMarkers();
        _updateCamera(_destinationLocation!, 15.0);
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
        'https://rsapi.goong.io/Direction?origin=${_currentLocation.lat},${_currentLocation.lng}&destination=${_destinationLocation!.lat},${_destinationLocation!.lng}&vehicle=car&api_key=$apiKey');

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
        List<List<double>> coordinates =
        result.map((point) => [point.longitude, point.latitude]).toList();

        String geojson = '''{
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

        await _mapboxMap?.style.addSource(GeoJsonSource(id: "route_source", data: geojson));
        var lineLayerJson = """{
          "type": "line",
          "id": "route_layer",
          "source": "route_source",
          "paint": {
            "line-join": "round",
            "line-cap": "round",
            "line-color": "#4A90E2",
            "line-width": 8.0
          }
        }""";
        await _mapboxMap?.style.addPersistentStyleLayer(lineLayerJson, null);

        _mapboxMap?.setCamera(CameraOptions(
          center: Point(coordinates: _currentLocation).toJson(),
          zoom: 14.0,
        ));
      }
    } catch (e) {
      debugPrint("Lỗi lấy đường đi: $e");
    }
  }

  Future<void> _clearRoute() async {
    try {
      await _mapboxMap?.style.removeStyleLayer("route_layer");
      await _mapboxMap?.style.removeStyleSource("route_source");
    } catch (e) {
      // Bỏ qua nếu layer chưa tồn tại
    }
  }

  void _startNavigation() async {
    setState(() {
      _currentState = MapState.navigating;
    });

    await _fetchAndDrawRoute();

    _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: _currentLocation).toJson(),
          zoom: 17.0,
          pitch: 45.0,
        ),
        MapAnimationOptions(duration: 1000)
    );
  }

  void _resetToExplore() {
    setState(() {
      _currentState = MapState.explore;
      _destinationLocation = null;
      _searchController.clear();
      _searchResults.clear();
    });
    _clearRoute();
    _drawMarkers();

    _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: _currentLocation).toJson(),
          zoom: 16.0,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 500)
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Scaffold(
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
          SafeArea(
            child: Stack(
              children: [
                if (_currentState == MapState.explore || _currentState == MapState.placeDetail)
                  _buildSearchBar(),
                if (_currentState == MapState.navigating)
                  _buildNavigationTopBar(),
                if (_currentState == MapState.placeDetail)
                  _buildPlaceDetailSheet(),
                if (_currentState == MapState.navigating)
                  _buildNavigationBottomPanel(),
              ],
            ),
          ),
        ],
      ),

      // 🌟 THAY ĐỔI: Chuyển FloatingActionButton thành dạng Column để chứa 2 nút
      floatingActionButton: _currentState != MapState.navigating
          ? Padding(
        padding: EdgeInsets.only(
            bottom: _currentState == MapState.placeDetail ? 250.0 : 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nút Vệ Tinh (Skyview)
            FloatingActionButton(
              heroTag: "btn_satellite", // Phải có tag để tránh lỗi trùng lặp FAB
              backgroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SatelliteScreen()),
                );
              },
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.orange),
            ),
            const SizedBox(height: 12),
            // Nút Vị trí hiện tại
            FloatingActionButton(
              heroTag: "btn_location",
              backgroundColor: Colors.white,
              onPressed: () {
                if (_isLocationLoaded) {
                  _updateCamera(_currentLocation, 16.0);
                } else {
                  _getUserLocation();
                }
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ],
        ),
      )
          : null,
    );
  }

  // ========================== CÁC WIDGET GIAO DIỆN ==========================
  Widget _buildSearchBar() {
    return Positioned(
      top: 10, left: 15, right: 15,
      child: Column(
        children: [
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                if (_currentState == MapState.placeDetail)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                    onPressed: _resetToExplore,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search_rounded, color: Colors.indigo, size: 24),
                  ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: "Tìm kiếm điểm đến...",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                  )
                else if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                      _resetToExplore();
                    },
                  ),
                const SizedBox(width: 5),
                const CircleAvatar(
                  backgroundColor: Colors.indigoAccent,
                  radius: 18,
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    var place = _searchResults[index];
                    String mainText = place['structured_formatting']?['main_text'] ?? place['description'] ?? "";
                    String secondaryText = place['structured_formatting']?['secondary_text'] ?? "";

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.indigo, size: 20),
                      ),
                      title: Text(
                        mainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      subtitle: secondaryText.isNotEmpty
                          ? Text(
                        secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      )
                          : null,
                      onTap: () => _selectPlace(place['place_id'], place['description']),
                    );
                  },
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPlaceDetailSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _destinationName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _destinationAddress,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.indigo),
                )
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.indigo, Colors.indigoAccent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                      label: const Text(
                        "Bắt đầu",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _startNavigation,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.indigo.shade200, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.route_rounded, color: Colors.indigo),
                      label: const Text(
                        "Đường đi",
                        style: TextStyle(color: Colors.indigo, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _fetchAndDrawRoute,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTopBar() {
    return Positioned(
      top: 15, left: 15, right: 15,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.turn_right_rounded, color: Colors.greenAccent, size: 32),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Đang hướng tới",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _destinationName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBottomPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 20),
            child: FloatingActionButton.extended(
              heroTag: "vision_btn",
              backgroundColor: Colors.indigoAccent,
              elevation: 8,
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: const Text(
                "GNSS-Vision",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FlowScreen()),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 35),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _duration,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.green),
                      ),
                      Text(
                        "Khoảng cách: $_distance",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _resetToExplore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade100.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Thoát",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}