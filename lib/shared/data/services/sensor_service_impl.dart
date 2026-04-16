import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import 'sensor_service.dart';

class SensorServiceImpl implements SensorService {
  final StreamController<double> _accelYController =
      StreamController<double>.broadcast();

  double _currentAccelY = 0.0;
  bool _isInitialized = false;

  @override
  Future<Either<Failure, double>> getAccelY() async {
    return Right(_currentAccelY);
  }

  @override
  Future<Either<Failure, bool>> isAvailable() async {
    return Right(_isInitialized);
  }

  @override
  Stream<double> get accelYStream => _accelYController.stream;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _accelYController.close();
    _isInitialized = false;
  }

  void updateAccelY(double value) {
    _currentAccelY = value;
    _accelYController.add(value);
  }
}
