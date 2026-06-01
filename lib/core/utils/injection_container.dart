import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/login_with_google.dart';
import '../../features/auth/domain/usecases/logout.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Tránh đăng ký lại nếu đã được khởi tạo (hữu ích khi Activity restart)
  if (sl.isRegistered<Box<Map>>(instanceName: 'tripsBox')) {
    return;
  }
  
  // Đăng ký các dịch vụ ngoại vi một cách lười biếng (Lazy)
  _initExternalDependencies();
  
  initAuthFeature();
  initVisionFeature();
  initTripFeature();
  initSharedServices();
}

void _initExternalDependencies() {
  // Firebase Auth
  sl.registerLazySingleton(() => FirebaseAuth.instance);

  // Sử dụng registerSingletonAsync nếu cần khởi tạo bất đồng bộ nhưng vẫn muốn đảm bảo duy nhất
  sl.registerSingletonAsync<Box<Map>>(
    () => Hive.openBox<Map>('trips'),
    instanceName: 'tripsBox',
  );
  sl.registerSingletonAsync<Box<Map>>(
    () => Hive.openBox<Map>('media_files'),
    instanceName: 'mediaBox',
  );
}

void initAuthFeature() {
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(auth: sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));

  // BLoC
  sl.registerFactory(
    () => AuthBloc(
      getCurrentUser: sl(),
      loginWithGoogle: sl(),
      logout: sl(),
    ),
  );
}

void initVisionFeature() {
  // Vision feature will be initialized here when migrated from FlowController
  // For now, legacy FlowController is used via Provider in main.dart
}

void initTripFeature() {
  // Trip feature will be initialized here when fully migrated to BLoC
  // For now, legacy TripController is used via Provider in main.dart
}

void initSharedServices() {
  // Shared services registered here when migrated
}
