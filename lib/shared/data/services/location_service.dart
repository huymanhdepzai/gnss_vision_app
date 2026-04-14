import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

abstract class LocationService {
  Future<Either<Failure, double>> getCurrentHeading();

  Future<Either<Failure, double>> getCurrentSpeed();

  Future<Either<Failure, double>> getAccuracy();

  Future<Either<Failure, bool>> hasPermission();

  Future<Either<Failure, bool>> isServiceEnabled();

  Stream<double> get headingStream;

  Stream<double> get speedStream;

  Stream<double> get accuracyStream;
}
