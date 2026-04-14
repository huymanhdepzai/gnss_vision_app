import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'motion_vector.dart';
import 'obstacle.dart';

class FrameResult extends Equatable {
  final List<Offset> trackedPoints;
  final MotionVector motionVector;
  final List<Obstacle> obstacles;
  final double fusedHeading;
  final double speed;
  final bool hasValidGps;
  final bool isModelLoaded;
  final bool voiceEnabled;
  final Duration timestamp;

  const FrameResult({
    required this.trackedPoints,
    required this.motionVector,
    required this.obstacles,
    required this.fusedHeading,
    required this.speed,
    required this.hasValidGps,
    required this.isModelLoaded,
    required this.voiceEnabled,
    required this.timestamp,
  });

  FrameResult copyWith({
    List<Offset>? trackedPoints,
    MotionVector? motionVector,
    List<Obstacle>? obstacles,
    double? fusedHeading,
    double? speed,
    bool? hasValidGps,
    bool? isModelLoaded,
    bool? voiceEnabled,
    Duration? timestamp,
  }) {
    return FrameResult(
      trackedPoints: trackedPoints ?? this.trackedPoints,
      motionVector: motionVector ?? this.motionVector,
      obstacles: obstacles ?? this.obstacles,
      fusedHeading: fusedHeading ?? this.fusedHeading,
      speed: speed ?? this.speed,
      hasValidGps: hasValidGps ?? this.hasValidGps,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    trackedPoints,
    motionVector,
    obstacles,
    fusedHeading,
    speed,
    hasValidGps,
    isModelLoaded,
    voiceEnabled,
    timestamp,
  ];
}
