import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  double _smoothedHeading = 0.0;
  bool _isMapReady = false;
  bool _arrowIconReady = false;

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
      final raw = widget.headingNotifier!.value;
      _smoothedHeading = _smoothAngle(_smoothedHeading, raw, 0.3);
      _currentHeading = _smoothedHeading;
      _updateCameraBearing(_smoothedHeading);
    }
  }

  double _smoothAngle(double oldAngle, double newAngle, double factor) {
    double diff = newAngle - oldAngle;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (oldAngle + diff * factor + 360) % 360;
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
            distanceFilter: 2,
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
    _mapboxMap!.easeTo(
      CameraOptions(bearing: bearing),
      MapAnimationOptions(duration: 600),
    );
  }

  void _animateCameraToPosition(geo.Position position) {
    _mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ).toJson(),
        zoom: 17.8,
        pitch: 65.0,
        bearing: _currentHeading,
        padding: MbxEdgeInsets(top: 50, left: 0, bottom: 280, right: 0),
      ),
      MapAnimationOptions(duration: 1200),
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
          zoom: 17.8,
          pitch: 65.0,
          bearing: _currentHeading,
          padding: MbxEdgeInsets(top: 50, left: 0, bottom: 280, right: 0),
        ),
      );
    }
  }

  List<double> _computeArrowBearings(List<List<double>> polyline) {
    final arrows = <double>[];
    if (polyline.length < 2) return arrows;

    final List<double> cumulativeDistances = [0.0];
    double totalDistance = 0.0;
    for (int i = 1; i < polyline.length; i++) {
      final d = _haversineDistance(
        polyline[i - 1][1], polyline[i - 1][0],
        polyline[i][1], polyline[i][0],
      );
      totalDistance += d;
      cumulativeDistances.add(totalDistance);
    }

    if (totalDistance < 50) return arrows;

    final double arrowSpacing = totalDistance > 2000 ? 350.0 : 200.0;
    final double startOffset = 30.0;

    double dist = startOffset;
    while (dist < totalDistance - 20) {
      int segIdx = 0;
      for (int i = 1; i < cumulativeDistances.length; i++) {
        if (cumulativeDistances[i] >= dist) {
          segIdx = i - 1;
          break;
        }
      }

      if (segIdx >= polyline.length - 1) break;

      double bearing = _computeBearing(
        polyline[segIdx][1], polyline[segIdx][0],
        polyline[segIdx + 1][1], polyline[segIdx + 1][0],
      );

      arrows.add(bearing);
      dist += arrowSpacing;
    }

    return arrows;
  }

  String _buildArrowGeoJson(List<List<double>> polyline) {
    if (polyline.length < 2) return '{"type":"FeatureCollection","features":[]}';

    final List<double> cumulativeDistances = [0.0];
    double totalDistance = 0.0;
    for (int i = 1; i < polyline.length; i++) {
      final d = _haversineDistance(
        polyline[i - 1][1], polyline[i - 1][0],
        polyline[i][1], polyline[i][0],
      );
      totalDistance += d;
      cumulativeDistances.add(totalDistance);
    }

    if (totalDistance < 50) return '{"type":"FeatureCollection","features":[]}';

    final double arrowSpacing = totalDistance > 2000 ? 350.0 : 200.0;
    final double startOffset = 30.0;

    final features = <String>[];
    double dist = startOffset;

    while (dist < totalDistance - 20) {
      int segIdx = 0;
      for (int i = 1; i < cumulativeDistances.length; i++) {
        if (cumulativeDistances[i] >= dist) {
          segIdx = i - 1;
          break;
        }
      }

      if (segIdx >= polyline.length - 1) break;

      final segStartDist = cumulativeDistances[segIdx];
      final segEndDist = cumulativeDistances[segIdx + 1];
      final segLen = segEndDist - segStartDist;
      if (segLen < 0.001) { dist += arrowSpacing; continue; }

      final t = (dist - segStartDist) / segLen;
      final lng = polyline[segIdx][0] + t * (polyline[segIdx + 1][0] - polyline[segIdx][0]);
      final lat = polyline[segIdx][1] + t * (polyline[segIdx + 1][1] - polyline[segIdx][1]);

      double bearing = _computeBearing(
        polyline[segIdx][1], polyline[segIdx][0],
        polyline[segIdx + 1][1], polyline[segIdx + 1][0],
      );

      features.add('''{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [$lng, $lat]
        },
        "properties": {
          "bearing": $bearing
        }
      }''');

      dist += arrowSpacing;
    }

    return '''{
      "type": "FeatureCollection",
      "features": [${features.join(',')}]
    }''';
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _computeBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final y = sin(dLon) * cos(lat2 * pi / 180);
    final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);
    final brng = atan2(y, x) * 180 / pi;
    return (brng + 360) % 360;
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
          circleColor: const Color(0xFF1565C0).withOpacity(0.12).value,
          circleRadius: 40.0,
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
          circleColor: const Color(0xFF1976D2).withOpacity(0.25).value,
          circleRadius: 26.0,
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
          circleColor: const Color(0xFF1565C0).value,
          circleRadius: 16.0,
          circleStrokeWidth: 4.0,
          circleStrokeColor: Colors.white.value,
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
          circleColor: const Color(0xFF42A5F5).value,
          circleRadius: 8.0,
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
          circleColor: Colors.white.value,
          circleRadius: 3.5,
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
          circleColor: AppTheme.accentColor.withOpacity(0.15).value,
          circleRadius: 20.0,
        ),
      );
      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              route.destinationLongitude,
              route.destinationLatitude,
            ),
          ).toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 12.0,
          circleStrokeWidth: 3.0,
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

    _arrowIconReady = await _addArrowIcon();

    setState(() => _isMapReady = true);

    if (widget.route != null) {
      await _drawRouteAndMarkers();
    }
  }

  Future<bool> _addArrowIcon() async {
    if (_mapboxMap == null) return false;
    try {
      final int size = 48;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final center = Offset(size / 2, size / 2);
      final path = Path();
      path.moveTo(center.dx, center.dy - 18);
      path.lineTo(center.dx + 12, center.dy + 8);
      path.lineTo(center.dx + 5, center.dy + 4);
      path.lineTo(center.dx + 5, center.dy + 14);
      path.lineTo(center.dx - 5, center.dy + 14);
      path.lineTo(center.dx - 5, center.dy + 4);
      path.lineTo(center.dx - 12, center.dy + 8);
      path.close();

      final shadowPaint = Paint()
        ..color = const Color(0xFF1565C0)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, shadowPaint);

      final highlightPaint = Paint()
        ..color = const Color(0xFF64B5F6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, highlightPaint);

      final picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(size, size);
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        debugPrint('Arrow icon: byteData is null');
        return false;
      }

      final rgbaData = byteData.buffer.asUint8List();

      await _mapboxMap!.style.addStyleImage(
        "nav_direction_arrow",
        1.0,
        MbxImage(width: size, height: size, data: rgbaData),
        false,
        [],
        [],
        null,
      );
      return true;
    } catch (e) {
      debugPrint('Error adding arrow icon: $e');
      return false;
    }
  }

  Future<void> _drawRoute(NavigationRoute route) async {
    if (_mapboxMap == null) return;

    await _clearRoute();

    String routeGeojson =
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

    String arrowGeojson = _buildArrowGeoJson(route.polyline);

    try {
      await _mapboxMap?.style.addSource(
        GeoJsonSource(id: "nav_route_source", data: routeGeojson),
      );

      if (_arrowIconReady) {
        await _mapboxMap?.style.addSource(
          GeoJsonSource(id: "nav_arrow_source", data: arrowGeojson),
        );
      }

      var innerGlowJson = """{
        "type": "line",
        "id": "nav_route_inner_glow",
        "source": "nav_route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#1565C0",
          "line-width": 28.0,
          "line-opacity": 0.15,
          "line-blur": 6.0
        }
      }""";

      var outerGlowJson = """{
        "type": "line",
        "id": "nav_route_outer_glow",
        "source": "nav_route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#1976D2",
          "line-width": 20.0,
          "line-opacity": 0.25,
          "line-blur": 4.0
        }
      }""";

      var casingLayerJson = """{
        "type": "line",
        "id": "nav_route_casing",
        "source": "nav_route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#FFFFFF",
          "line-width": 16.0,
          "line-opacity": 0.8
        }
      }""";

      var lineLayerJson = """{
        "type": "line",
        "id": "nav_route_layer",
        "source": "nav_route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#2979FF",
          "line-width": 12.0,
          "line-opacity": 1.0
        }
      }""";

      var centerHighlightJson = """{
        "type": "line",
        "id": "nav_route_highlight",
        "source": "nav_route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#64B5F6",
          "line-width": 4.0,
          "line-opacity": 0.7,
          "line-blur": 1.0
        }
      }""";

      await _mapboxMap?.style.addPersistentStyleLayer(innerGlowJson, null);
      await _mapboxMap?.style.addPersistentStyleLayer(outerGlowJson, null);
      await _mapboxMap?.style.addPersistentStyleLayer(casingLayerJson, null);
      await _mapboxMap?.style.addPersistentStyleLayer(lineLayerJson, null);
      await _mapboxMap?.style.addPersistentStyleLayer(centerHighlightJson, null);

      if (_arrowIconReady) {
        var arrowLayerJson = """{
          "type": "symbol",
          "id": "nav_arrow_layer",
          "source": "nav_arrow_source",
          "layout": {
            "symbol-placement": "point",
            "icon-image": "nav_direction_arrow",
            "icon-size": 0.9,
            "icon-rotation": ["get", "bearing"],
            "icon-rotation-alignment": "map",
            "icon-allow-overlap": true,
            "icon-ignore-placement": true,
            "icon-keep-upright": false
          },
          "paint": {
            "icon-opacity": 0.95
          }
        }""";

        await _mapboxMap?.style.addPersistentStyleLayer(arrowLayerJson, null);
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  Future<void> _clearRoute() async {
    try {
      await _mapboxMap?.style.removeStyleLayer("nav_arrow_layer");
      await _mapboxMap?.style.removeStyleLayer("nav_route_highlight");
      await _mapboxMap?.style.removeStyleLayer("nav_route_layer");
      await _mapboxMap?.style.removeStyleLayer("nav_route_casing");
      await _mapboxMap?.style.removeStyleLayer("nav_route_outer_glow");
      await _mapboxMap?.style.removeStyleLayer("nav_route_inner_glow");
      await _mapboxMap?.style.removeStyleSource("nav_route_source");
      await _mapboxMap?.style.removeStyleSource("nav_arrow_source");
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
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ),
      ),
    );
  }
}