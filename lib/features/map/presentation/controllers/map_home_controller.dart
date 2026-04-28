import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../data/datasources/goong_search_data_source.dart';
import '../controllers/navigation_controller.dart';

enum MapViewState { explore, placeDetail, navigating }

class MapHomeController extends ChangeNotifier {
  final GoongSearchDataSource _searchDataSource;
  final NavigationController _navigationController;

  MapHomeController({
    required GoongSearchDataSource searchDataSource,
    required NavigationController navigationController,
  })  : _searchDataSource = searchDataSource,
        _navigationController = navigationController;

  NavigationController get navigationController => _navigationController;

  Position _currentLocation = Position(105.804817, 21.028511);
  Position get currentLocation => _currentLocation;

  bool _isLocationLoaded = false;
  bool get isLocationLoaded => _isLocationLoaded;

  StreamSubscription<geo.Position>? _positionStream;

  MapViewState _currentState = MapViewState.explore;
  MapViewState get currentState => _currentState;

  String _destinationName = '';
  String get destinationName => _destinationName;

  String _destinationAddress = '';
  String get destinationAddress => _destinationAddress;

  Position? _destinationLocation;
  Position? get destinationLocation => _destinationLocation;

  String _distance = '\u0110ang t\u00ednh...';
  String get distance => _distance;

  String _duration = '-- ph\u00fat';
  String get duration => _duration;

  String? _routeGeoJson;
  String? get routeGeoJson => _routeGeoJson;

  bool _isRouteActive = false;
  bool get isRouteActive => _isRouteActive;

  List<SearchResult> _searchResults = [];
  List<SearchResult> get searchResults => _searchResults;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Timer? _debounce;

  Future<void> initLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.deniedForever) return;

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _updateLocation(position);
    } catch (e) {
      debugPrint('Error getting initial location: $e');
    }

    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _updateLocation(position);
    });
  }

  void _updateLocation(geo.Position position) {
    _currentLocation = Position(position.longitude, position.latitude);
    _isLocationLoaded = true;
    notifyListeners();
  }

  void onSearchChanged(String query) {
    _debounce?.cancel();
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchPlaces(query);
    });
  }

  Future<void> searchPlaces(String query) async {
    _isSearching = true;
    notifyListeners();

    try {
      final results = await _searchDataSource.autocomplete(
        query,
        lat: _currentLocation.lat.toDouble(),
        lng: _currentLocation.lng.toDouble(),
        radius: 50,
      );
      _searchResults = results;
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> selectPlace(String placeId, String description) async {
    _isSearching = true;
    _searchResults = [];
    _searchQuery = description;
    notifyListeners();

    try {
      final detail = await _searchDataSource.getPlaceDetail(placeId);
      _destinationLocation = Position(detail.longitude, detail.latitude);
      _destinationName = detail.name.isNotEmpty ? detail.name : description;
      _destinationAddress = detail.address;
      _currentState = MapViewState.placeDetail;
      notifyListeners();
    } catch (e) {
      debugPrint('Place detail error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> fetchRoute() async {
    if (_destinationLocation == null) return;
    _isSearching = true;
    notifyListeners();

    try {
      await _navigationController.fetchRouteAndStart(
        originLat: _currentLocation.lat.toDouble(),
        originLng: _currentLocation.lng.toDouble(),
        destinationLat: _destinationLocation!.lat.toDouble(),
        destinationLng: _destinationLocation!.lng.toDouble(),
        destinationName: _destinationName,
      );

      final route = _navigationController.currentRoute;
      if (route != null) {
        _distance = route.distanceText;
        _duration = route.durationText;
        _routeGeoJson = '''{
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": ${route.polyline}
              }
            }
          ]
        }''';
        _isRouteActive = true;
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void startNavigation() {
    _currentState = MapViewState.navigating;
    notifyListeners();
  }

  Future<void> fetchAndDrawRoute() async {
    await fetchRoute();
  }

  void resetToExplore() {
    _navigationController.stopNavigation();
    _currentState = MapViewState.explore;
    _destinationLocation = null;
    _destinationName = '';
    _destinationAddress = '';
    _distance = '\u0110ang t\u00ednh...';
    _duration = '-- ph\u00fat';
    _routeGeoJson = null;
    _isRouteActive = false;
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    resetToExplore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}