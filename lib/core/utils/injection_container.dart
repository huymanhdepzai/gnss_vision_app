import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/authenticate_with_biometrics.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/is_biometric_enabled.dart';
import '../../features/auth/domain/usecases/login_with_google.dart';
import '../../features/auth/domain/usecases/logout.dart';
import '../../features/auth/domain/usecases/set_biometric_enabled.dart';
import '../../features/auth/domain/usecases/sign_in_silently.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/trip/data/datasources/firestore_data_source.dart';
import '../../features/trip/data/datasources/trip_local_data_source.dart';
import '../../features/trip/data/datasources/trip_local_data_source_impl.dart';
import '../../features/trip/data/repositories/trip_repository_impl.dart';
import '../../features/trip/domain/repositories/trip_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Tránh đăng ký lại nếu đã được khởi tạo
  if (sl.isRegistered<Box<Map>>(instanceName: 'tripsBox')) {
    return;
  }
  
  // Đăng ký các dịch vụ ngoại vi
  await _initExternalDependencies();
  
  initAuthFeature();
  initVisionFeature();
  initTripFeature();
  initSharedServices();
}

Future<void> _initExternalDependencies() async {
  // Firebase Auth
  sl.registerLazySingleton(() => FirebaseAuth.instance);

  // Local Auth
  sl.registerLazySingleton(() => LocalAuthentication());

  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Hive
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
    () => AuthRemoteDataSourceImpl(
      auth: sl(),
      localAuth: sl(),
      sharedPreferences: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => AuthenticateWithBiometricsUseCase(sl()));
  sl.registerLazySingleton(() => IsBiometricEnabledUseCase(sl()));
  sl.registerLazySingleton(() => SetBiometricEnabledUseCase(sl()));
  sl.registerLazySingleton(() => SignInSilentlyUseCase(sl()));

  // BLoC
  sl.registerFactory(
    () => AuthBloc(
      getCurrentUser: sl(),
      loginWithGoogle: sl(),
      logout: sl(),
      authenticateWithBiometrics: sl(),
      isBiometricEnabled: sl(),
      setBiometricEnabled: sl(),
      signInSilently: sl(),
    ),
  );
}

void initVisionFeature() {
  // Vision feature will be initialized here when migrated from FlowController
  // For now, legacy FlowController is used via Provider in main.dart
}

void initTripFeature() {
  // Data sources
  sl.registerLazySingleton<TripLocalDataSource>(
    () => TripLocalDataSourceImpl(
      tripsBox: sl(instanceName: 'tripsBox'),
      mediaBox: sl(instanceName: 'mediaBox'),
    ),
  );
  sl.registerLazySingleton<FirestoreDataSource>(() => FirestoreDataSource());

  // Repository
  sl.registerLazySingleton<TripRepository>(
    () => TripRepositoryImpl(
      localDataSource: sl(),
      authRemoteDataSource: sl(),
      firestoreDataSource: sl(),
    ),
  );
}

void initSharedServices() {
  // Shared services registered here when migrated
}
