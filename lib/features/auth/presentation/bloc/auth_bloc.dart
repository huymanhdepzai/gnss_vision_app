import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/logout.dart';

part 'auth_bloc.freezed.dart'; // Bắt buộc phải có để build_runner sinh code

// --- EVENTS ---
@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.authCheckRequested() = _AuthCheckRequested;
  const factory AuthEvent.loginWithGoogleRequested() = _LoginWithGoogleRequested;
  const factory AuthEvent.logoutRequested() = _LogoutRequested;
}

// --- STATES ---
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}

// --- BLOC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUseCase getCurrentUser;
  final LoginWithGoogleUseCase loginWithGoogle;
  final LogoutUseCase logout;

  AuthBloc({
    required this.getCurrentUser,
    required this.loginWithGoogle,
    required this.logout,
  }) : super(const AuthState.initial()) {

    on<_AuthCheckRequested>((event, emit) async {
      final result = await getCurrentUser();
      result.fold(
            (failure) => emit(AuthState.unauthenticated()),
            (user) => user != null
            ? emit(AuthState.authenticated(user))
            : emit(const AuthState.unauthenticated()),
      );
    });

    on<_LoginWithGoogleRequested>((event, emit) async {
      emit(const AuthState.loading());
      final result = await loginWithGoogle();
      result.fold(
            (failure) {
          // Bỏ qua lỗi nếu user cố tình hủy dialog Google
          if (failure.message.contains('hủy')) {
            emit(const AuthState.unauthenticated());
          } else {
            emit(AuthState.error(failure.message));
          }
        },
            (user) => emit(AuthState.authenticated(user)),
      );
    });

    on<_LogoutRequested>((event, emit) async {
      emit(const AuthState.loading());
      await logout();
      emit(const AuthState.unauthenticated());
    });
  }
}