import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class VisionFailure extends Failure {
  const VisionFailure({required super.message, super.code});
}

class CameraFailure extends Failure {
  const CameraFailure({required super.message, super.code});
}

class AIFailure extends Failure {
  const AIFailure({required super.message, super.code});
}

class SensorFailure extends Failure {
  const SensorFailure({required super.message, super.code});
}

class LocationFailure extends Failure {
  const LocationFailure({required super.message, super.code});
}

class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({String? message})
    : super(message: message ?? 'An unknown error occurred');
}
