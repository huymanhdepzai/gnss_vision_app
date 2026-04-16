import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/frame_result_model.dart';

abstract class CVDataSource {
  Future<Either<Failure, FrameResultModel>> processFrame();

  Future<void> initialize();

  Future<void> dispose();

  Future<void> loadVideo(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(double position);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> reset();

  Stream<Uint8List?> get frameStream;

  bool get isPlaying;

  double get totalFrames;

  double get currentFrame;
}

abstract class AIDataSource {
  Future<Either<Failure, List<Map<String, dynamic>>>> detectObjects(
    Uint8List imageBytes,
  );

  Future<void> initialize();

  Future<void> dispose();

  bool get isModelLoaded;
}

abstract class SensorDataSource {
  Future<Either<Failure, double>> getGpsHeading();

  Future<Either<Failure, double>> getGpsSpeed();

  Future<Either<Failure, double>> getGpsAccuracy();

  Future<Either<Failure, double>> getImuAccelY();

  Future<Either<Failure, bool>> hasValidGps();

  Future<void> initialize();

  Future<void> dispose();
}
