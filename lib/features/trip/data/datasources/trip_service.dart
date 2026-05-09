import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/injection_container.dart';
import '../models/trip.dart';
import '../models/media_file.dart';

class TripService {
  static const String _tripsBoxName = 'trips';
  static const String _mediaBoxName = 'media_files';

  Box<Map> get _tripsBox => sl<Box<Map>>(instanceName: 'tripsBox');
  Box<Map> get _mediaBox => sl<Box<Map>>(instanceName: 'mediaBox');

  // Không cần static initialize nữa vì đã dùng GetIt singleton async
  static Future<void> initialize() async {
    // Để trống để tránh lỗi ở các nơi đang gọi, hoặc xóa đi
  }

  Future<List<Trip>> getAllTrips() async {
    final box = _tripsBox;
    // ... rest of the code stays the same, but remove the null check if we are sure box is open
    // However, since it's async, we might need to wait for sl.allReady()
    
    final trips = box.values.map((dynamic item) {
      final json = Map<String, dynamic>.from(item as Map);
      return Trip.fromJson(json);
    }).toList();

    trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return trips;
  }
  
  // Update other methods as well to use the getter
  Future<Trip?> getTripById(String id) async {
    final box = _tripsBox;
    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        final json = Map<String, dynamic>.from(item as Map);
        if (json['id'] == id) {
          return Trip.fromJson(json);
        }
      }
    }
    return null;
  }

  Future<void> saveTrip(Trip trip) async {
    await _tripsBox.put(trip.id, trip.toJson());
  }

  Future<void> deleteTrip(String id) async {
    await _tripsBox.delete(id);

    final mediaBox = _mediaBox;
    final keysToDelete = <dynamic>[];
    for (var key in mediaBox.keys) {
      final item = mediaBox.get(key);
      if (item != null) {
        final json = Map<String, dynamic>.from(item as Map);
        if (json['tripId'] == id) {
          keysToDelete.add(key);
        }
      }
    }
    for (var key in keysToDelete) {
      await mediaBox.delete(key);
    }
  }

  Future<List<MediaFile>> getMediaFilesForTrip(String tripId) async {
    final box = _mediaBox;
    final mediaFiles = <MediaFile>[];
    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        final json = Map<String, dynamic>.from(item as Map);
        if (json['tripId'] == tripId) {
          mediaFiles.add(MediaFile.fromJson(json));
        }
      }
    }

    mediaFiles.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return mediaFiles;
  }

  Future<void> saveMediaFile(MediaFile mediaFile) async {
    await _mediaBox.put(mediaFile.id, mediaFile.toJson());
  }

  Future<void> deleteMediaFile(String mediaId) async {
    await _mediaBox.delete(mediaId);
  }

  Future<void> updateTripMediaIds(
    String tripId,
    List<String> mediaFileIds,
  ) async {
    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds = mediaFileIds;
      await _tripsBox.put(tripId, trip.toJson());
    }
  }

  Future<void> addMediaToTrip(String tripId, String mediaId) async {
    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds.add(mediaId);
      await _tripsBox.put(tripId, trip.toJson());
    }
  }

  Future<void> removeMediaFromTrip(String tripId, String mediaId) async {
    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds.remove(mediaId);
      await _tripsBox.put(tripId, trip.toJson());
    }
  }
}
