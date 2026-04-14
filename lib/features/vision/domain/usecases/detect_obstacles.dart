import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/obstacle.dart';
import '../repositories/vision_repository.dart';

class DetectObstacles {
  final VisionRepository repository;

  DetectObstacles(this.repository);

  Future<Either<Failure, List<Obstacle>>> call() async {
    return await repository.detectObstacles();
  }
}
