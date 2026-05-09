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
  final ValueNotifier<bool>? headingUpNotifier;

  const NavigationMapWidget({
    Key? key,
    this.headingNotifier,
    this.onExitNavigation,
    this.route,
    this.headingUpNotifier,
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
  bool _userIconReady = false;
  bool _isHeadingUp = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    if (widget.headingNotifier != null) {
      widget.headingNotifier!.addListener(_onHeadingChanged);
    }
    if (widget.headingUpNotifier != null) {
      _isHeadingUp = widget.headingUpNotifier!.value;
      widget.headingUpNotifier!.addListener(_onHeadingUpChanged);
    }
  }

  @override
  void didUpdateWidget(NavigationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != oldWidget.route && _isMapReady) {
      _drawRouteAndMarkers();
    }
    if (widget.headingNotifier != oldWidget.headingNotifier) {
      oldWidget.headingNotifier?.removeListener(_onHeadingChanged);
      widget.headingNotifier?.addListener(_onHeadingChanged);
    }
    if (widget.headingUpNotifier != oldWidget.headingUpNotifier) {
      oldWidget.headingUpNotifier?.removeListener(_onHeadingUpChanged);
      widget.headingUpNotifier?.addListener(_onHeadingUpChanged);
    }
  }

  void _onHeadingChanged() {
    if (_isMapReady && mounted && widget.headingNotifier != null) {
      final raw = widget.headingNotifier!.value;
      _smoothedHeading = _smoothAngle(_smoothedHeading, raw, 0.3);
      _currentHeading = _smoothedHeading;
      if (_isHeadingUp) {
        _updateCameraBearing(_smoothedHeading);
      }
      _updateUserLocationMarker();
    }
  }

  void _onHeadingUpChanged() {
    if (widget.headingUpNotifier != null) {
      final newValue = widget.headingUpNotifier!.value;
      if (_isHeadingUp != newValue) {
        setState(() => _isHeadingUp = newValue);
        if (_isMapReady && mounted) {
          if (_isHeadingUp) {
            _updateCameraBearing(_currentHeading);
            if (_currentPosition != null) {
              _mapboxMap?.easeTo(
                CameraOptions(
                  center: Point(
                    coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude),
                  ).toJson(),
                  zoom: 17.8,
                  pitch: 65.0,
                  bearing: _currentHeading,
                  padding: MbxEdgeInsets(top: 50, left: 0, bottom: 280, right: 0),
                ),
                MapAnimationOptions(duration: 800),
              );
            }
          } else {
            if (_currentPosition != null) {
              _mapboxMap?.easeTo(
                CameraOptions(
                  center: Point(
                    coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude),
                  ).toJson(),
                  zoom: 16.0,
                  pitch: 0.0,
                  bearing: 0.0,
                ),
                MapAnimationOptions(duration: 800),
              );
            } else {
              _updateCameraBearing(0.0);
            }
          }
        }
      }
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
    _isDisposed = true;
    _positionStream?.cancel();
    if (widget.headingNotifier != null) {
      widget.headingNotifier!.removeListener(_onHeadingChanged);
    }
    if (widget.headingUpNotifier != null) {
      widget.headingUpNotifier!.removeListener(_onHeadingUpChanged);
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
            _updateUserLocationMarker();
            _animateCameraToPosition(position);
          }
        });
  }

  void _updateCameraBearing(double bearing) {
    if (_mapboxMap == null) return;
    if (_isHeadingUp) {
      _mapboxMap!.easeTo(
        CameraOptions(bearing: bearing, pitch: 65.0),
        MapAnimationOptions(duration: 600),
      );
    } else {
      _mapboxMap!.easeTo(
        CameraOptions(bearing: 0.0, pitch: 0.0),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  void _animateCameraToPosition(geo.Position position) {
    if (_isHeadingUp) {
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
    } else {
      _mapboxMap?.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ).toJson(),
          zoom: 16.0,
          pitch: 0.0,
          bearing: 0.0,
        ),
        MapAnimationOptions(duration: 1200),
      );
    }
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

    if (totalDistance < 20) return '{"type":"FeatureCollection","features":[]}';

    final double arrowSpacing = totalDistance > 2000 ? 150.0 : 80.0;
    final double startOffset = 15.0;

    final features = <String>[];
    double dist = startOffset;

    while (dist < totalDistance - 10) {
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

  bool _isInitializingStyle = false;
  bool _isDisposed = false;

  void _onStyleLoaded(StyleLoadedEventData data) async {
    if (_isInitializingStyle || _isDisposed) return;
    _isInitializingStyle = true;

    try {
      debugPrint('Map style loaded, initializing layers...');
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _isDisposed || _mapboxMap == null) return;

      _circleAnnotationManager = await _mapboxMap?.annotations.createCircleAnnotationManager();

      if (!mounted || _isDisposed) return;

      _arrowIconReady = await _addArrowIcon();

      if (!mounted || _isDisposed) return;

      await _addUserNavigationIcon();

      if (!mounted || _isDisposed) return;

      setState(() => _isMapReady = true);

      if (widget.route != null) {
        await _drawRouteAndMarkers();
      }

      if (_currentPosition != null) {
        _updateUserLocationMarker();
      }
    } catch (e) {
      debugPrint('Error initializing map style: $e');
    } finally {
      _isInitializingStyle = false;
    }
  }

  Future<Uint8List?> _generateNavArrowImage({
    required int size,
    Color primaryColor = const Color(0xFF2979FF),
    Color secondaryColor = const Color(0xFF1565C0),
    bool showGlow = true,
    bool isUserIcon = true,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final cx = size / 2.0;
      final s = size / 200.0;

      if (showGlow && isUserIcon) {
        canvas.drawCircle(
          Offset(cx, cx),
          48 * s,
          Paint()..color = primaryColor.withOpacity(0.12),
        );
        canvas.drawCircle(
          Offset(cx, cx),
          34 * s,
          Paint()..color = primaryColor.withOpacity(0.18),
        );
        canvas.drawCircle(
          Offset(cx, cx),
          22 * s,
          Paint()..color = primaryColor.withOpacity(0.10),
        );
      }

      final arrowPath = Path();
      arrowPath.moveTo(cx, 14 * s);
      arrowPath.lineTo(cx + 34 * s, cx + 28 * s);
      arrowPath.lineTo(cx + 11 * s, cx + 8 * s);
      arrowPath.lineTo(cx + 11 * s, cx + 48 * s);
      arrowPath.lineTo(cx - 11 * s, cx + 48 * s);
      arrowPath.lineTo(cx - 11 * s, cx + 8 * s);
      arrowPath.lineTo(cx - 34 * s, cx + 28 * s);
      arrowPath.close();

      canvas.save();
      canvas.translate(1.5 * s, 2.5 * s);
      canvas.drawPath(
        arrowPath,
        Paint()..color = Colors.black.withOpacity(0.3),
      );
      canvas.restore();

      if (isUserIcon) {
        final fillPaint = Paint()..style = PaintingStyle.fill;
        fillPaint.shader = ui.Gradient.linear(
          Offset(cx, 14 * s),
          Offset(cx, cx + 48 * s),
          [primaryColor, secondaryColor],
        );
        canvas.drawPath(arrowPath, fillPaint);

        final highlightPath = Path();
        highlightPath.moveTo(cx, 22 * s);
        highlightPath.lineTo(cx + 16 * s, cx + 12 * s);
        highlightPath.lineTo(cx, cx - 2 * s);
        highlightPath.lineTo(cx - 16 * s, cx + 12 * s);
        highlightPath.close();
        canvas.drawPath(
          highlightPath,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.white.withOpacity(0.3),
        );
      } else {
        canvas.drawPath(
          arrowPath,
          Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFFFFFF),
        );
        canvas.drawPath(
          arrowPath,
          Paint()
            ..style = PaintingStyle.fill
            ..color = primaryColor.withOpacity(0.15),
        );
      }

      canvas.drawPath(
        arrowPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isUserIcon ? 2.5 * s : 2.0 * s
          ..color = isUserIcon ? Colors.white : primaryColor.withOpacity(0.7)
          ..strokeJoin = StrokeJoin.round,
      );

      if (isUserIcon) {
        canvas.drawCircle(
          Offset(cx, cx + 2 * s),
          4 * s,
          Paint()..color = Colors.white.withOpacity(0.85),
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return Uint8List.fromList(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    } catch (e) {
      debugPrint('Error generating nav arrow image: $e');
      return null;
    }
  }

  Future<bool> _addArrowIcon() async {
    if (_mapboxMap == null || _isDisposed) return false;
    try {
      debugPrint('Generating route arrow icon...');
      final pngBytes = await _generateNavArrowImage(
        size: 80,
        primaryColor: const Color(0xFF2979FF),
        secondaryColor: const Color(0xFF1565C0),
        showGlow: false,
        isUserIcon: false,
      );

      if (pngBytes == null || !mounted || _isDisposed || _mapboxMap == null) return false;

      final imageWidth = 80;
      final imageHeight = 80;

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await _mapboxMap!.style.addStyleImage(
            "nav_direction_arrow",
            1.0,
            MbxImage(width: imageWidth, height: imageHeight, data: pngBytes),
            false,
            [],
            [],
            null,
          );
          debugPrint('Route arrow icon generated and added.');
          return true;
        } catch (e) {
          debugPrint('Arrow icon add attempt ${attempt + 1} failed: $e');
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            if (!mounted || _isDisposed || _mapboxMap == null) return false;
          }
        }
      }
      debugPrint('Error adding arrow icon after 3 retries');
      return false;
    } catch (e) {
      debugPrint('Error adding arrow icon: $e');
      return false;
    }
  }

  Future<void> _addUserNavigationIcon() async {
    if (_mapboxMap == null || _isDisposed) return;
    try {
      debugPrint('Generating user navigation arrow icon...');
      final pngBytes = await _generateNavArrowImage(
        size: 200,
        primaryColor: const Color(0xFF2979FF),
        secondaryColor: const Color(0xFF0D47A1),
        showGlow: true,
        isUserIcon: true,
      );

      if (pngBytes == null || !mounted || _isDisposed || _mapboxMap == null) return;

      final imageWidth = 200;
      final imageHeight = 200;

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await _mapboxMap!.style.addStyleImage(
            "user_navigation_icon",
            1.0,
            MbxImage(width: imageWidth, height: imageHeight, data: pngBytes),
            false,
            [],
            [],
            null,
          );
          _userIconReady = true;
          debugPrint('User navigation arrow icon generated and added.');
          return;
        } catch (e) {
          debugPrint('User icon add attempt ${attempt + 1} failed: $e');
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            if (!mounted || _isDisposed || _mapboxMap == null) return;
          }
        }
      }
      debugPrint('Error adding user navigation icon after 3 retries');
    } catch (e) {
      debugPrint('Error adding user navigation icon: $e');
    }
  }

  Future<void> _updateUserLocationMarker() async {
    if (_mapboxMap == null || _currentPosition == null || !_userIconReady) return;

    String geojson = '''{
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [${_currentPosition!.longitude}, ${_currentPosition!.latitude}]
      },
      "properties": {
        "bearing": $_currentHeading
      }
    }''';

    String accuracyGeojson = '''{
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [${_currentPosition!.longitude}, ${_currentPosition!.latitude}]
      },
      "properties": {
        "accuracy": ${min(_currentPosition!.accuracy, 50.0)}
      }
    }''';

    try {
      final style = _mapboxMap!.style;

      if (await style.styleSourceExists("user_accuracy_source")) {
        await style.setStyleSourceProperty("user_accuracy_source", "data", accuracyGeojson);
      } else {
        await style.addSource(GeoJsonSource(id: "user_accuracy_source", data: accuracyGeojson));

        if (!(await style.styleLayerExists("user_accuracy_layer"))) {
          var accuracyLayerJson = """{
            "type": "circle",
            "id": "user_accuracy_layer",
            "source": "user_accuracy_source",
            "paint": {
              "circle-radius": ["interpolate", ["linear"], ["get", "accuracy"], 5, 8, 50, 60],
              "circle-color": "#2979FF",
              "circle-opacity": 0.08,
              "circle-pitch-alignment": "map"
            }
          }""";
          await style.addPersistentStyleLayer(accuracyLayerJson, null);
        }
      }

      if (await style.styleSourceExists("user_location_source")) {
        await style.setStyleSourceProperty("user_location_source", "data", geojson);
      } else {
        await style.addSource(GeoJsonSource(id: "user_location_source", data: geojson));

        if (!(await style.styleLayerExists("user_location_layer"))) {
          var layerJson = """{
            "type": "symbol",
            "id": "user_location_layer",
            "source": "user_location_source",
            "layout": {
              "icon-image": "user_navigation_icon",
              "icon-size": 0.35,
              "icon-rotate": ["get", "bearing"],
              "icon-rotation-alignment": "map",
              "icon-allow-overlap": true,
              "icon-ignore-placement": true
            }
          }""";
          await style.addPersistentStyleLayer(layerJson, null);
        }
      }

      if (await style.styleLayerExists("user_location_layer")) {
        await style.moveStyleLayer("user_location_layer", null);
      }
    } catch (e) {
      debugPrint('Error updating user location marker: $e');
    }
  }

  Future<void> _drawRoute(NavigationRoute route) async {
    if (_mapboxMap == null) return;

    debugPrint('Drawing navigation route...');
    await _clearRoute();

    List<List<double>> routeCoords = route.polyline;
    if (_currentPosition != null) {
      routeCoords = [
        [_currentPosition!.longitude, _currentPosition!.latitude],
        ...route.polyline,
      ];
    }

    String routeGeojson =
        '''{
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": $routeCoords
          }
        }
      ]
    }''';

    String arrowGeojson = _buildArrowGeoJson(routeCoords);

    try {
      final style = _mapboxMap!.style;

      await style.addSource(GeoJsonSource(id: "nav_route_source", data: routeGeojson));

      if (_arrowIconReady) {
        await style.addSource(GeoJsonSource(id: "nav_arrow_source", data: arrowGeojson));
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

      await style.addPersistentStyleLayer(innerGlowJson, null);
      await style.addPersistentStyleLayer(outerGlowJson, null);
      await style.addPersistentStyleLayer(casingLayerJson, null);
      await style.addPersistentStyleLayer(lineLayerJson, null);
      await style.addPersistentStyleLayer(centerHighlightJson, null);

      if (_arrowIconReady) {
        var arrowLayerJson = """{
          "type": "symbol",
          "id": "nav_arrow_layer",
          "source": "nav_arrow_source",
          "layout": {
            "symbol-placement": "point",
            "icon-image": "nav_direction_arrow",
            "icon-size": 0.6,
            "icon-rotate": ["get", "bearing"],
            "icon-rotation-alignment": "map",
            "icon-pitch-alignment": "map",
            "icon-allow-overlap": true,
            "icon-ignore-placement": true,
            "icon-keep-upright": false
          },
          "paint": {
            "icon-opacity": 0.95
          }
        }""";

        await style.addPersistentStyleLayer(arrowLayerJson, null);
        debugPrint('Navigation arrow layer added with icon.');
      }

      // Ensure user location is on top
      if (await style.styleLayerExists("user_location_layer")) {
        await style.moveStyleLayer("user_location_layer", null);
      }
      debugPrint('Route drawing complete.');
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  Future<void> _clearRoute() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    final layers = [
      "nav_arrow_layer",
      "nav_route_highlight",
      "nav_route_layer",
      "nav_route_casing",
      "nav_route_outer_glow",
      "nav_route_inner_glow"
    ];

    for (final layerId in layers) {
      try {
        if (await style.styleLayerExists(layerId)) {
          await style.removeStyleLayer(layerId);
        }
      } catch (_) {}
    }

    final sources = ["nav_route_source", "nav_arrow_source"];
    for (final sourceId in sources) {
      try {
        if (await style.styleSourceExists(sourceId)) {
          await style.removeStyleSource(sourceId);
        }
      } catch (_) {}
    }
  }  @override
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