import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/frame_result.dart';
import '../repositories/vision_repository.dart';

class ProcessFrame {
  final VisionRepository repository;

  ProcessFrame(this.repository);

  Future<Either<Failure, FrameResult>> call() async {
    return await repository.processFrame();
  }
}
