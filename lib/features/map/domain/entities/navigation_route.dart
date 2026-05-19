import 'package:equatable/equatable.dart';
import 'navigation_step.dart';

class NavigationRoute extends Equatable {
  final String id;
  final double totalDistance;
  final double totalDuration;
  final String distanceText;
  final String durationText;
  final List<NavigationStep> steps;
  final List<List<double>> polyline;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationName;

  const NavigationRoute({
    required this.id,
    required this.totalDistance,
    required this.totalDuration,
    required this.distanceText,
    required this.durationText,
    required this.steps,
    required this.polyline,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationName,
  });

  NavigationRoute copyWith({
    String? id,
    double? totalDistance,
    double? totalDuration,
    String? distanceText,
    String? durationText,
    List<NavigationStep>? steps,
    List<List<double>>? polyline,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationName,
  }) {
    return NavigationRoute(
      id: id ?? this.id,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      distanceText: distanceText ?? this.distanceText,
      durationText: durationText ?? this.durationText,
      steps: steps ?? this.steps,
      polyline: polyline ?? this.polyline,
      originLatitude: originLatitude ?? this.originLatitude,
      originLongitude: originLongitude ?? this.originLongitude,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationName: destinationName ?? this.destinationName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    totalDistance,
    totalDuration,
    distanceText,
    durationText,
    steps,
    polyline,
    originLatitude,
    originLongitude,
    destinationLatitude,
    destinationLongitude,
    destinationName,
  ];
}
