import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../domain/entities/saved_address_entity.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  
  // Saved Addresses
  Future<void> updateHomeAddress(SavedAddressEntity address);
  Future<void> updateWorkAddress(SavedAddressEntity address);
  
  // Biometric methods
  Future<bool> authenticateWithBiometrics();
  Future<bool> isDeviceBiometricAvailable();
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
      
      return await _getUserModelFromFirebaseUser(userCredential.user!);
    } catch (e) {
      throw Exception('Lỗi đăng nhập Google: $e');
    }
  }

  Future<UserModel> _getUserModelFromFirebaseUser(User firebaseUser) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
      SavedAddressEntity? home;
      SavedAddressEntity? work;
      if (doc.exists) {
        final data = doc.data()!;
        if (data['homeAddress'] != null) home = SavedAddressEntity.fromJson(data['homeAddress']);
        if (data['workAddress'] != null) work = SavedAddressEntity.fromJson(data['workAddress']);
      }
      return UserModel.fromFirebaseUser(
        firebaseUser,
        homeAddress: home,
        workAddress: work,
      );
    } catch (e) {
      debugPrint('Lỗi lấy dữ liệu từ Firestore: $e');
      return UserModel.fromFirebaseUser(firebaseUser);
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

      return await _getUserModelFromFirebaseUser(userCredential.user!);
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
  Future<bool> isDeviceBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await localAuth.getAvailableBiometrics();
      
      return (canCheckBiometrics || isDeviceSupported) && availableBiometrics.isNotEmpty;
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
      return await _getUserModelFromFirebaseUser(user);
    }
    return null;
  }

  @override
  Future<void> updateHomeAddress(SavedAddressEntity address) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Vui lòng đăng nhập');
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'homeAddress': address.toJson(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateWorkAddress(SavedAddressEntity address) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Vui lòng đăng nhập');
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'workAddress': address.toJson(),
    }, SetOptions(merge: true));
  }
}
