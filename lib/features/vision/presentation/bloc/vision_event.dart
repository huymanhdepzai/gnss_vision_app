import 'package:equatable/equatable.dart';
import '../../domain/entities/frame_result.dart';
import '../../domain/entities/obstacle.dart';

abstract class VisionEvent extends Equatable {
  const VisionEvent();

  @override
  List<Object?> get props => [];
}

class InitializeVision extends VisionEvent {
  const InitializeVision();
}

class LoadVideo extends VisionEvent {
  final String videoPath;
  const LoadVideo(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

class PlayVideo extends VisionEvent {
  const PlayVideo();
}

class PauseVideo extends VisionEvent {
  const PauseVideo();
}

class SeekVideo extends VisionEvent {
  final double position;
  const SeekVideo(this.position);

  @override
  List<Object?> get props => [position];
}

class SetPlaybackSpeed extends VisionEvent {
  final double speed;
  const SetPlaybackSpeed(this.speed);

  @override
  List<Object?> get props => [speed];
}

class ResetVision extends VisionEvent {
  const ResetVision();
}

class ToggleVoice extends VisionEvent {
  const ToggleVoice();
}

class ToggleDebugMode extends VisionEvent {
  const ToggleDebugMode();
}

class FrameProcessed extends VisionEvent {
  final FrameResult result;
  const FrameProcessed(this.result);

  @override
  List<Object?> get props => [result];
}

class ObstaclesDetected extends VisionEvent {
  final List<Obstacle> obstacles;
  const ObstaclesDetected(this.obstacles);

  @override
  List<Object?> get props => [obstacles];
}

class HeadingUpdated extends VisionEvent {
  final double heading;
  const HeadingUpdated(this.heading);

  @override
  List<Object?> get props => [heading];
}

class ErrorOccurred extends VisionEvent {
  final String message;
  const ErrorOccurred(this.message);

  @override
  List<Object?> get props => [message];
}
