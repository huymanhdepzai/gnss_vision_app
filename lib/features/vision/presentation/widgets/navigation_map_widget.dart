import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../map/presentation/controllers/navigation_controller.dart';
import '../../../map/domain/entities/navigation_route.dart';

class NavigationMapWidget extends StatefulWidget {
  final ValueNotifier<double>? headingNotifier;
  final VoidCallback? onExitNavigation;
  final NavigationRoute? route;

  const NavigationMapWidget({
    Key? key,
    this.headingNotifier,
    this.onExitNavigation,
    this.route,
  }) : super(key: key);

  @override
  State<NavigationMapWidget> createState() => _NavigationMapWidgetState();
}

class _NavigationMapWidgetState extends State<NavigationMapWidget> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  StreamSubscription<geo.Position>? _positionStream;
  geo.Position? _currentPosition;
  double _currentHeading = 0.0;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    if (widget.headingNotifier != null) {
      widget.headingNotifier!.addListener(_onHeadingChanged);
    }
  }

  @override
  void didUpdateWidget(NavigationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != oldWidget.route && _isMapReady) {
      _drawRouteAndMarkers();
    }
  }

  void _onHeadingChanged() {
    if (_isMapReady && mounted && widget.headingNotifier != null) {
      _currentHeading = widget.headingNotifier!.value;
      _updateCameraBearing(widget.headingNotifier!.value);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    if (widget.headingNotifier != null) {
      widget.headingNotifier!.removeListener(_onHeadingChanged);
    }
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _currentPosition = position;
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    _positionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 3,
          ),
        ).listen((geo.Position position) {
          if (!mounted) return;
          _currentPosition = position;
          if (_isMapReady) {
            _redrawMarkers();
            _animateCameraToPosition(position);
          }
        });
  }

  void _updateCameraBearing(double bearing) {
    if (_mapboxMap == null) return;
    _mapboxMap!.setCamera(CameraOptions(bearing: bearing));
  }

  void _animateCameraToPosition(geo.Position position) {
    _mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ).toJson(),
        zoom: 17.0,
        pitch: 45.0,
        bearing: _currentHeading,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _drawRouteAndMarkers() async {
    final route = widget.route;
    if (route == null) return;

    await _drawRoute(route);
    await _redrawMarkers();

    if (_currentPosition != null) {
      _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ).toJson(),
          zoom: 17.0,
          pitch: 45.0,
          bearing: _currentHeading,
        ),
      );
    }
  }

  Future<void> _redrawMarkers() async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager!.deleteAll();

    final route = widget.route;

    if (_currentPosition != null) {
      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ).toJson(),
          circleColor: AppTheme.secondaryColor.withOpacity(0.3).value,
          circleRadius: 16.0,
        ),
      );
      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    if (route != null) {
      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              route.destinationLongitude,
              route.destinationLatitude,
            ),
          ).toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
    mapboxMap.loadStyleURI(
      'https://tiles.goong.io/assets/navigation_night.json?api_key=$mapTilesKey',
    );
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager = await _mapboxMap?.annotations
        .createCircleAnnotationManager();

    setState(() => _isMapReady = true);

    if (widget.route != null) {
      await _drawRouteAndMarkers();
    }
  }

  Future<void> _drawRoute(NavigationRoute route) async {
    if (_mapboxMap == null) return;

    await _clearRoute();

    String geojson =
        '''{
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

    try {
      await _mapboxMap?.style.addSource(
        GeoJsonSource(id: "nav_route_source", data: geojson),
      );

      var lineLayerJson = """{
        "type": "line",
        "id": "nav_route_layer",
        "source": "nav_route_source",
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
      debugPrint('Error drawing route: $e');
    }
  }

  Future<void> _clearRoute() async {
    try {
      await _mapboxMap?.style.removeStyleLayer("nav_route_layer");
      await _mapboxMap?.style.removeStyleSource("nav_route_source");
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: MapWidget(
            key: const ValueKey("navigationMapWidget"),
            resourceOptions: ResourceOptions(accessToken: mapboxToken),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
        ),
        Positioned(top: 8, right: 8, child: _buildExitButton()),
      ],
    );
  }

  Widget _buildExitButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            widget.onExitNavigation ??
            () {
              final navController = context.read<NavigationController>();
              navController.stopNavigation();
            },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
