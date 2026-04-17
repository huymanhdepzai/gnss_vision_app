import '../../domain/entities/navigation_route.dart';
import '../../domain/entities/navigation_step.dart';

class NavigationRouteModel extends NavigationRoute {
  const NavigationRouteModel({
    required super.id,
    required super.totalDistance,
    required super.totalDuration,
    required super.distanceText,
    required super.durationText,
    required super.steps,
    required super.polyline,
    required super.originLatitude,
    required super.originLongitude,
    required super.destinationLatitude,
    required super.destinationLongitude,
    required super.destinationName,
  });

  factory NavigationRouteModel.fromJson(
    Map<String, dynamic> json, {
    String? destinationName,
  }) {
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const FormatException('No routes found in response');
    }

    final route = routes[0];
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) {
      throw const FormatException('No legs found in route');
    }

    final leg = legs[0];

    double totalDistanceValue = 0;
    double totalDurationValue = 0;
    String distanceStr = '';
    String durationStr = '';

    final distData = leg['distance'];
    if (distData is Map) {
      totalDistanceValue = (distData['value'] as num?)?.toDouble() ?? 0;
      distanceStr = distData['text']?.toString() ?? '';
    } else if (distData is num) {
      totalDistanceValue = distData.toDouble();
      distanceStr = '${(totalDistanceValue / 1000).toStringAsFixed(1)} km';
    }

    final durData = leg['duration'];
    if (durData is Map) {
      totalDurationValue = (durData['value'] as num?)?.toDouble() ?? 0;
      durationStr = durData['text']?.toString() ?? '';
    } else if (durData is num) {
      totalDurationValue = durData.toDouble();
      final mins = (totalDurationValue / 60).round();
      durationStr = '$mins phút';
    }

    final steps = <NavigationStep>[];
    final stepsJson = leg['steps'] as List<dynamic>? ?? [];
    for (final stepJson in stepsJson) {
      steps.add(_parseStep(stepJson as Map<String, dynamic>));
    }

    final overviewPolyline =
        route['overview_polyline']?['points'] as String? ?? '';
    final polyline = _decodePolyline(overviewPolyline);

    final originCoord = leg['start_location'] as Map<String, dynamic>?;
    final destCoord = leg['end_location'] as Map<String, dynamic>?;

    double originLat = 0, originLng = 0;
    if (originCoord != null) {
      originLat = originCoord['lat']?.toDouble() ?? 0;
      originLng = originCoord['lng']?.toDouble() ?? 0;
    }
    double destLat = 0, destLng = 0;
    if (destCoord != null) {
      destLat = destCoord['lat']?.toDouble() ?? 0;
      destLng = destCoord['lng']?.toDouble() ?? 0;
    }

    return NavigationRouteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      totalDistance: totalDistanceValue,
      totalDuration: totalDurationValue,
      distanceText: distanceStr,
      durationText: durationStr,
      steps: steps,
      polyline: polyline,
      originLatitude: originLat,
      originLongitude: originLng,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      destinationName: destinationName ?? '',
    );
  }

  static NavigationStep _parseStep(Map<String, dynamic> json) {
    String maneuverType = 'depart';
    String? maneuverModifier;

    final maneuverData = json['maneuver'];
    if (maneuverData is Map<String, dynamic>) {
      maneuverType = maneuverData['type']?.toString() ?? 'depart';
      maneuverModifier = maneuverData['modifier']?.toString();
    } else if (maneuverData is String) {
      maneuverType = maneuverData;
    }

    final startLocation = json['start_location'];
    double startLat = 0, startLng = 0;
    if (startLocation is Map<String, dynamic>) {
      startLat = startLocation['lat']?.toDouble() ?? 0;
      startLng = startLocation['lng']?.toDouble() ?? 0;
    }

    final endLocation = json['end_location'];
    double endLat = 0, endLng = 0;
    if (endLocation is Map<String, dynamic>) {
      endLat = endLocation['lat']?.toDouble() ?? 0;
      endLng = endLocation['lng']?.toDouble() ?? 0;
    }

    double distanceValue = 0;
    final distData = json['distance'];
    if (distData is Map) {
      distanceValue = (distData['value'] as num?)?.toDouble() ?? 0;
    } else if (distData is num) {
      distanceValue = distData.toDouble();
    }

    double durationValue = 0;
    final durData = json['duration'];
    if (durData is Map) {
      durationValue = (durData['value'] as num?)?.toDouble() ?? 0;
    } else if (durData is num) {
      durationValue = durData.toDouble();
    }

    String instruction =
        json['html_instructions']?.toString() ??
        json['html_instruction']?.toString() ??
        json['instruction']?.toString() ??
        '';

    return NavigationStep(
      instruction: instruction,
      distance: distanceValue,
      duration: durationValue,
      maneuverType: _parseManeuverType(maneuverType),
      maneuverModifier: maneuverModifier,
      startLatitude: startLat,
      startLongitude: startLng,
      endLatitude: endLat,
      endLongitude: endLng,
      name: json['name']?.toString(),
    );
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

  static List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([(lng / 1E5).toDouble(), (lat / 1E5).toDouble()]);
    }

    return points;
  }
}
