import 'package:dartz/dartz.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();
      return Right(userModel);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(Failure('Lỗi đăng xuất: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(Failure('Không thể kiểm tra trạng thái đăng nhập: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> authenticateWithBiometrics() async {
    try {
      final result = await remoteDataSource.authenticateWithBiometrics();
      return Right(result);
    } catch (e) {
      return Left(Failure('Lỗi xác thực sinh trắc học: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isDeviceBiometricAvailable() async {
    try {
      final result = await remoteDataSource.isDeviceBiometricAvailable();
      return Right(result);
    } catch (e) {
      return Left(Failure('Lỗi kiểm tra sinh trắc học thiết bị: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInSilently() async {
    try {
      final userModel = await remoteDataSource.signInSilently();
      return Right(userModel);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setBiometricEnabled(bool enabled) async {
    try {
      await remoteDataSource.setBiometricEnabled(enabled);
      return const Right(null);
    } catch (e) {
      return Left(Failure('Không thể lưu cài đặt sinh trắc học: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isBiometricEnabled() async {
    try {
      final result = await remoteDataSource.isBiometricEnabled();
      return Right(result);
    } catch (e) {
      return Left(Failure('Không thể đọc cài đặt sinh trắc học: $e'));
    }
  }
}