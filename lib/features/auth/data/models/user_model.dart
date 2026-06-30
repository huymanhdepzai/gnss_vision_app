import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/saved_address_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.id,
    super.email,
    super.displayName,
    super.photoUrl,
    super.homeAddress,
    super.workAddress,
  });

  factory UserModel.fromFirebaseUser(
    firebase.User firebaseUser, {
    SavedAddressEntity? homeAddress,
    SavedAddressEntity? workAddress,
  }) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      homeAddress: homeAddress,
      workAddress: workAddress,
    );
  }
}