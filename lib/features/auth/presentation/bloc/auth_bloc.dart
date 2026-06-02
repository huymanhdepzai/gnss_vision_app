import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/authenticate_with_biometrics.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/is_biometric_enabled.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/set_biometric_enabled.dart';
import '../../domain/usecases/sign_in_silently.dart';

part 'auth_bloc.freezed.dart';

// --- EVENTS ---
@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.authCheckRequested() = _AuthCheckRequested;
  const factory AuthEvent.loginWithGoogleRequested() = _LoginWithGoogleRequested;
  const factory AuthEvent.logoutRequested() = _LogoutRequested;
  
  // Biometric Events
  const factory AuthEvent.biometricLoginRequested() = _BiometricLoginRequested;
  const factory AuthEvent.toggleBiometricRequested(bool enabled) = _ToggleBiometricRequested;
  const factory AuthEvent.checkBiometricStatusRequested() = _CheckBiometricStatusRequested;
}

// --- STATES ---
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserEntity user, {@Default(false) bool isBiometricEnabled}) = _Authenticated;
  const factory AuthState.unauthenticated({@Default(false) bool isBiometricEnabled}) = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}

// --- BLOC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUseCase getCurrentUser;
  final LoginWithGoogleUseCase loginWithGoogle;
  final LogoutUseCase logout;
  
  // New Use Cases
  final AuthenticateWithBiometricsUseCase authenticateWithBiometrics;
  final IsBiometricEnabledUseCase isBiometricEnabled;
  final SetBiometricEnabledUseCase setBiometricEnabled;
  final SignInSilentlyUseCase signInSilently;

  AuthBloc({
    required this.getCurrentUser,
    required this.loginWithGoogle,
    required this.logout,
    required this.authenticateWithBiometrics,
    required this.isBiometricEnabled,
    required this.setBiometricEnabled,
    required this.signInSilently,
  }) : super(const AuthState.initial()) {

    on<_AuthCheckRequested>((event, emit) async {
      final result = await getCurrentUser();
      final bioStatusResult = await isBiometricEnabled();
      final isBioEnabled = bioStatusResult.getOrElse(() => false);
      
      result.fold(
            (failure) => emit(AuthState.unauthenticated(isBiometricEnabled: isBioEnabled)),
            (user) => user != null
            ? emit(AuthState.authenticated(user, isBiometricEnabled: isBioEnabled))
            : emit(AuthState.unauthenticated(isBiometricEnabled: isBioEnabled)),
      );
    });

    on<_LoginWithGoogleRequested>((event, emit) async {
      emit(const AuthState.loading());
      final result = await loginWithGoogle();
      
      final bioStatusResult = await isBiometricEnabled();
      final isBioEnabled = bioStatusResult.getOrElse(() => false);

      result.fold(
            (failure) {
          if (failure.message.contains('hủy')) {
            emit(AuthState.unauthenticated(isBiometricEnabled: isBioEnabled));
          } else {
            emit(AuthState.error(failure.message));
          }
        },
            (user) => emit(AuthState.authenticated(user, isBiometricEnabled: isBioEnabled)),
      );
    });

    on<_LogoutRequested>((event, emit) async {
      emit(const AuthState.loading());
      await logout();
      
      final bioStatusResult = await isBiometricEnabled();
      final isBioEnabled = bioStatusResult.getOrElse(() => false);
      
      emit(AuthState.unauthenticated(isBiometricEnabled: isBioEnabled));
    });

    // Biometric Logic
    on<_CheckBiometricStatusRequested>((event, emit) async {
      final result = await isBiometricEnabled();
      result.fold(
        (_) => null,
        (enabled) {
          state.maybeWhen(
            unauthenticated: (_) => emit(AuthState.unauthenticated(isBiometricEnabled: enabled)),
            authenticated: (user, _) => emit(AuthState.authenticated(user, isBiometricEnabled: enabled)),
            orElse: () {},
          );
        },
      );
    });

    on<_ToggleBiometricRequested>((event, emit) async {
      await setBiometricEnabled(event.enabled);
      add(const AuthEvent.checkBiometricStatusRequested());
    });

    on<_BiometricLoginRequested>((event, emit) async {
      final bioResult = await authenticateWithBiometrics();
      
      final bioStatusResult = await isBiometricEnabled();
      final isBioEnabled = bioStatusResult.getOrElse(() => false);

      await bioResult.fold(
        (failure) async => emit(AuthState.error(failure.message)),
        (success) async {
          if (success) {
            emit(const AuthState.loading());
            final loginResult = await signInSilently();
            loginResult.fold(
              (failure) => emit(AuthState.error(failure.message)),
              (user) => emit(AuthState.authenticated(user, isBiometricEnabled: isBioEnabled)),
            );
          }
        },
      );
    });
  }
}