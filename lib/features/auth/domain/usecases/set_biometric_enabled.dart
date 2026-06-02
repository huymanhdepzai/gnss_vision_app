import 'package:dartz/dartz.dart';
import '../repositories/auth_repository.dart';

class SetBiometricEnabledUseCase {
  final AuthRepository repository;

  SetBiometricEnabledUseCase(this.repository);

  Future<Either<Failure, void>> call(bool enabled) async {
    return await repository.setBiometricEnabled(enabled);
  }
}
