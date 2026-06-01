import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth auth;

  // Không cần truyền GoogleSignIn vào nữa vì chúng ta dùng Singleton instance
  AuthRemoteDataSourceImpl({required this.auth});

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // 1. Gọi hàm authenticate() từ Singleton instance
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 2. Lấy idToken từ Authentication (áp dụng fix từ lỗi trước)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Truyền idToken cho Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Không thể lấy thông tin User từ Firebase');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);

    } on GoogleSignInException catch (e) {
      // Firebase/Google ném lỗi này nếu user bấm nút Back để hủy hộp thoại đăng nhập
      throw Exception('Người dùng đã hủy quá trình đăng nhập hoặc có lỗi: ${e.code}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  @override
  Future<void> signOut() async {
    // Sử dụng instance để taođăng xuất
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