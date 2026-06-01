import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';

class Failure {
  final String message;
  Failure(this.message);
}

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, UserEntity?>> getCurrentUser();
}