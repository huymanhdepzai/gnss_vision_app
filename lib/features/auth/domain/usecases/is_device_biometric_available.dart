import 'package:dartz/dartz.dart';
import '../repositories/auth_repository.dart';

class IsDeviceBiometricAvailableUseCase {
  final AuthRepository repository;

  IsDeviceBiometricAvailableUseCase(this.repository);

  Future<Either<Failure, bool>> call() async {
    return await repository.isDeviceBiometricAvailable();
  }
}
