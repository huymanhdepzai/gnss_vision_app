import 'saved_address_entity.dart';

class UserEntity {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final SavedAddressEntity? homeAddress;
  final SavedAddressEntity? workAddress;

  UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.homeAddress,
    this.workAddress,
  });
}