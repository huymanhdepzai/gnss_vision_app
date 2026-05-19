import 'package:equatable/equatable.dart';

enum ManeuverType {
  depart,
  arrive,
  turn,
  fork,
  roundabout,
  merge,
  onRamp,
  offRamp,
  ferry,
  continueStraight,
  endOfRoad,
  newName,
  notification,
}

class NavigationStep extends Equatable {
  final String instruction;
  final double distance;
  final double duration;
  final ManeuverType maneuverType;
  final String? maneuverModifier;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String? name;

  const NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    this.maneuverModifier,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    this.name,
  });

  NavigationStep copyWith({
    String? instruction,
    double? distance,
    double? duration,
    ManeuverType? maneuverType,
    String? maneuverModifier,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? name,
  }) {
    return NavigationStep(
      instruction: instruction ?? this.instruction,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      maneuverType: maneuverType ?? this.maneuverType,
      maneuverModifier: maneuverModifier ?? this.maneuverModifier,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [
    instruction,
    distance,
    duration,
    maneuverType,
    maneuverModifier,
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    name,
  ];
}
