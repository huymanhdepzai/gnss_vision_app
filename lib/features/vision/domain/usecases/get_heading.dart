import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/vision_repository.dart';

class GetHeading {
  final VisionRepository repository;

  GetHeading(this.repository);

  Future<Either<Failure, double>> call() async {
    return await repository.getFusedHeading();
  }
}
