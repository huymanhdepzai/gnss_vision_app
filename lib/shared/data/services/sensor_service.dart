import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

abstract class SensorService {
  Future<Either<Failure, double>> getAccelY();

  Future<Either<Failure, bool>> isAvailable();

  Stream<double> get accelYStream;

  Future<void> initialize();

  Future<void> dispose();
}
