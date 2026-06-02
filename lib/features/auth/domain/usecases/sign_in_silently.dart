import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInSilentlyUseCase {
  final AuthRepository repository;

  SignInSilentlyUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    return await repository.signInSilently();
  }
}
