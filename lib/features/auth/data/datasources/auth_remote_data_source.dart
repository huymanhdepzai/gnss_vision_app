import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  
  // Biometric methods
  Future<bool> authenticateWithBiometrics();
  Future<UserModel> signInSilently();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> isBiometricEnabled();

  // Google API Client
  Future<http.Client?> getAuthenticatedClient();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth auth;
  final LocalAuthentication localAuth;
  final SharedPreferences sharedPreferences;

  static const String _biometricKey = 'is_biometric_enabled';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      'email',
    ],
  );

  AuthRemoteDataSourceImpl({
    required this.auth,
    required this.localAuth,
    required this.sharedPreferences,
  });

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Đăng nhập bị hủy bởi người dùng');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Không thể lấy thông tin User từ Firebase');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } catch (e) {
      throw Exception('Lỗi đăng nhập Google: $e');
    }
  }

  @override
  Future<UserModel> signInSilently() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

      if (googleUser == null) {
        // Nếu silent sign in thất bại, thử lại với signIn thông thường
        return await signInWithGoogle();
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Không thể lấy thông tin User từ Firebase');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } catch (e) {
      throw Exception('Lỗi đăng nhập nhanh: $e');
    }
  }

  @override
  Future<http.Client?> getAuthenticatedClient() async {
    try {
      // Nếu chưa có user trong session hiện tại, thử silent sign in
      if (_googleSignIn.currentUser == null) {
        debugPrint('AuthRemoteDataSource: currentUser is null, attempting silent sign in...');
        await _googleSignIn.signInSilently();
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('AuthRemoteDataSource: Failed to get authenticated client from google_sign_in');
      }
      return client;
    } catch (e) {
      debugPrint('AuthRemoteDataSource: Error getting authenticated client: $e');
      return null;
    }
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await localAuth.isDeviceSupported();

      if (!canAuthenticate) return false;

      return await localAuth.authenticate(
        localizedReason: 'Vui lòng xác thực để đăng nhập vào GNSS Vision',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await sharedPreferences.setBool(_biometricKey, enabled);
  }

  @override
  Future<bool> isBiometricEnabled() async {
    return sharedPreferences.getBool(_biometricKey) ?? false;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = auth.currentUser;
    if (user != null) {
      return UserModel.fromFirebaseUser(user);
    }
    return null;
  }
}
