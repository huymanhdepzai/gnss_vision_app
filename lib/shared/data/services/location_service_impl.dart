import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import 'location_service.dart';

class LocationServiceImpl implements LocationService {
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();
  final StreamController<double> _accuracyController =
      StreamController<double>.broadcast();

  double _currentHeading = 0.0;
  double _currentSpeed = 0.0;
  double _currentAccuracy = 0.0;

  @override
  Future<Either<Failure, double>> getCurrentHeading() async {
    return Right(_currentHeading);
  }

  @override
  Future<Either<Failure, double>> getCurrentSpeed() async {
    return Right(_currentSpeed);
  }

  @override
  Future<Either<Failure, double>> getAccuracy() async {
    return Right(_currentAccuracy);
  }

  @override
  Future<Either<Failure, bool>> hasPermission() async {
    return Right(true);
  }

  @override
  Future<Either<Failure, bool>> isServiceEnabled() async {
    return Right(true);
  }

  @override
  Stream<double> get headingStream => _headingController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  Stream<double> get accuracyStream => _accuracyController.stream;

  void updateHeading(double heading) {
    _currentHeading = heading;
    _headingController.add(heading);
  }

  void updateSpeed(double speed) {
    _currentSpeed = speed;
    _speedController.add(speed);
  }

  void updateAccuracy(double accuracy) {
    _currentAccuracy = accuracy;
    _accuracyController.add(accuracy);
  }

  void dispose() {
    _headingController.close();
    _speedController.close();
    _accuracyController.close();
  }
}
