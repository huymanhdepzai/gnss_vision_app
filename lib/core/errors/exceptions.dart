class AppException implements Exception {
  final String message;
  final int? code;
  final StackTrace? stackTrace;

  const AppException({required this.message, this.code, this.stackTrace});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class VisionException extends AppException {
  const VisionException({required super.message, super.code, super.stackTrace});
}

class CameraException extends AppException {
  const CameraException({required super.message, super.code, super.stackTrace});
}

class AIException extends AppException {
  const AIException({required super.message, super.code, super.stackTrace});
}

class SensorException extends AppException {
  const SensorException({required super.message, super.code, super.stackTrace});
}

class LocationException extends AppException {
  const LocationException({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

class CancelledException extends AppException {
  const CancelledException({String? message})
    : super(message: message ?? 'Operation was cancelled');
}

class TimeoutException extends AppException {
  const TimeoutException({String? message})
    : super(message: message ?? 'Operation timed out');
}
