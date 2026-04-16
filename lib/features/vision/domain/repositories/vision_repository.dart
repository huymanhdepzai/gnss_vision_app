import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/frame_result.dart';
import '../entities/obstacle.dart';
import '../entities/motion_vector.dart';

abstract class VisionRepository {
  Future<Either<Failure, FrameResult>> processFrame();

  Future<Either<Failure, List<Obstacle>>> detectObstacles();

  Future<Either<Failure, double>> getFusedHeading();

  Future<Either<Failure, MotionVector>> getMotionVector();

  Future<void> initialize();

  Future<void> dispose();

  Future<void> loadVideo(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(double position);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> reset();

  Stream<FrameResult> get frameStream;

  Stream<double> get headingStream;

  Stream<double> get progressStream;

  bool get isPlaying;

  bool get isPaused;

  bool get isModelLoaded;

  double get totalFrames;

  double get currentFrame;
}
