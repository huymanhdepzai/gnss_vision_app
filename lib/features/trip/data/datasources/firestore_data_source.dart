import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';
import '../models/media_file_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveTrip(String userId, TripModel trip) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .doc(trip.id)
        .set(trip.toJson());
  }

  Future<void> saveMediaFile(String userId, String tripId, MediaFileModel mediaFile) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .doc(tripId)
        .collection('media_files')
        .doc(mediaFile.id)
        .set(mediaFile.toJson());
  }

  Future<List<TripModel>> getSyncedTrips(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => TripModel.fromJson(doc.data())).toList();
  }

  Future<List<MediaFileModel>> getSyncedMediaFiles(String userId, String tripId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .doc(tripId)
        .collection('media_files')
        .get();

    return snapshot.docs.map((doc) => MediaFileModel.fromJson(doc.data())).toList();
  }

  Future<void> deleteTrip(String userId, String tripId) async {
    // Note: Deleting a document does not delete its subcollections in Firestore.
    // We should delete media_files first if we want to be clean, but for now we just delete the trip doc.
    final mediaDocs = await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .doc(tripId)
        .collection('media_files')
        .get();

    for (var doc in mediaDocs.docs) {
      await doc.reference.delete();
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('trips')
        .doc(tripId)
        .delete();
  }
}
