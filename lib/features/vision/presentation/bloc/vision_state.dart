import 'package:equatable/equatable.dart';
import '../../domain/entities/frame_result.dart';
import '../../domain/entities/obstacle.dart';

abstract class VisionState extends Equatable {
  const VisionState();

  @override
  List<Object?> get props => [];
}

class VisionInitial extends VisionState {
  const VisionInitial();
}

class VisionLoading extends VisionState {
  const VisionLoading();
}

class VisionReady extends VisionState {
  final bool isModelLoaded;
  final bool hasVideo;
  final double totalFrames;

  const VisionReady({
    required this.isModelLoaded,
    required this.hasVideo,
    required this.totalFrames,
  });

  @override
  List<Object?> get props => [isModelLoaded, hasVideo, totalFrames];
}

class VisionProcessing extends VisionState {
  final FrameResult frameResult;
  final List<Obstacle> obstacles;
  final double currentFrame;
  final double heading;
  final double speed;
  final bool isPaused;
  final bool voiceEnabled;
  final bool debugMode;
  final double progress;

  const VisionProcessing({
    required this.frameResult,
    required this.obstacles,
    required this.currentFrame,
    required this.heading,
    required this.speed,
    required this.isPaused,
    required this.voiceEnabled,
    required this.debugMode,
    required this.progress,
  });

  VisionProcessing copyWith({
    FrameResult? frameResult,
    List<Obstacle>? obstacles,
    double? currentFrame,
    double? heading,
    double? speed,
    bool? isPaused,
    bool? voiceEnabled,
    bool? debugMode,
    double? progress,
  }) {
    return VisionProcessing(
      frameResult: frameResult ?? this.frameResult,
      obstacles: obstacles ?? this.obstacles,
      currentFrame: currentFrame ?? this.currentFrame,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isPaused: isPaused ?? this.isPaused,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      debugMode: debugMode ?? this.debugMode,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [
    frameResult,
    obstacles,
    currentFrame,
    heading,
    speed,
    isPaused,
    voiceEnabled,
    debugMode,
    progress,
  ];
}

class VisionError extends VisionState {
  final String message;

  const VisionError(this.message);

  @override
  List<Object?> get props => [message];
}
