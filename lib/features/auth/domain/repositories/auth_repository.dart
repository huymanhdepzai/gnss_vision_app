import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../entities/saved_address_entity.dart';

class Failure {
  final String message;
  Failure(this.message);
}

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  
  // Saved Addresses
  Future<Either<Failure, void>> updateHomeAddress(SavedAddressEntity address);
  Future<Either<Failure, void>> updateWorkAddress(SavedAddressEntity address);
  
  // Biometric methods
  Future<Either<Failure, bool>> authenticateWithBiometrics();
  Future<Either<Failure, bool>> isDeviceBiometricAvailable();
  Future<Either<Failure, UserEntity>> signInSilently();
  Future<Either<Failure, void>> setBiometricEnabled(bool enabled);
  Future<Either<Failure, bool>> isBiometricEnabled();
}