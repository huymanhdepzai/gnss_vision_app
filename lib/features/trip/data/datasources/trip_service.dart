import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/media_file.dart';

class TripService {
  static const String _tripsBoxName = 'trips';
  static const String _mediaBoxName = 'media_files';

  static Box<Map>? _tripsBox;
  static Box<Map>? _mediaBox;

  static Future<void> initialize() async {
    _tripsBox = await Hive.openBox<Map>(_tripsBoxName);
    _mediaBox = await Hive.openBox<Map>(_mediaBoxName);
  }

  Future<List<Trip>> getAllTrips() async {
    final box = _tripsBox;
    if (box == null) return [];

    final trips = box.values.map((dynamic item) {
      final json = Map<String, dynamic>.from(item as Map);
      return Trip.fromJson(json);
    }).toList();

    trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return trips;
  }

  Future<Trip?> getTripById(String id) async {
    final box = _tripsBox;
    if (box == null) return null;

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
    final box = _tripsBox;
    if (box == null) return;

    await box.put(trip.id, trip.toJson());
  }

  Future<void> deleteTrip(String id) async {
    final box = _tripsBox;
    if (box == null) return;

    await box.delete(id);

    final mediaBox = _mediaBox;
    if (mediaBox != null) {
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
  }

  Future<List<MediaFile>> getMediaFilesForTrip(String tripId) async {
    final box = _mediaBox;
    if (box == null) return [];

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
    final box = _mediaBox;
    if (box == null) return;

    await box.put(mediaFile.id, mediaFile.toJson());
  }

  Future<void> deleteMediaFile(String mediaId) async {
    final box = _mediaBox;
    if (box == null) return;

    await box.delete(mediaId);
  }

  Future<void> updateTripMediaIds(
    String tripId,
    List<String> mediaFileIds,
  ) async {
    final box = _tripsBox;
    if (box == null) return;

    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds = mediaFileIds;
      await box.put(tripId, trip.toJson());
    }
  }

  Future<void> addMediaToTrip(String tripId, String mediaId) async {
    final box = _tripsBox;
    if (box == null) return;

    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds.add(mediaId);
      await box.put(tripId, trip.toJson());
    }
  }

  Future<void> removeMediaFromTrip(String tripId, String mediaId) async {
    final box = _tripsBox;
    if (box == null) return;

    final trip = await getTripById(tripId);
    if (trip != null) {
      trip.mediaFileIds.remove(mediaId);
      await box.put(tripId, trip.toJson());
    }
  }
}
