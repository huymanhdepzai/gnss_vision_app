import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth auth;
  final LocalAuthentication localAuth;
  final SharedPreferences sharedPreferences;

  static const String _biometricKey = 'is_biometric_enabled';

  AuthRemoteDataSourceImpl({
    required this.auth,
    required this.localAuth,
    required this.sharedPreferences,
  });

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
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
      // Vì bản GoogleSignIn này không có signInSilently, ta dùng authenticate()
      // Nếu version này hỗ trợ silent thông qua instance, hãy điều chỉnh sau.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
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
    await GoogleSignIn.instance.signOut();
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