import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/media_file.dart';
import '../services/trip_service.dart';
import '../services/media_service.dart';

class TripController extends ChangeNotifier {
  final TripService _tripService = TripService();
  final MediaService _mediaService = MediaService();

  List<Trip> _trips = [];
  Map<String, List<MediaFile>> _tripMedia = {};

  bool _isLoading = false;
  String? _error;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MediaFile> getMediaForTrip(String tripId) {
    return _tripMedia[tripId] ?? [];
  }

  Trip? getTripById(String id) {
    try {
      return _trips.firstWhere((trip) => trip.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadTrips() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _trips = await _tripService.getAllTrips();

      for (var trip in _trips) {
        _tripMedia[trip.id] = await _tripService.getMediaFilesForTrip(trip.id);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Trip?> createTrip({
    required String title,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String? startAddress,
    String? endAddress,
    double distance = 0,
    String duration = '',
  }) async {
    try {
      final trip = Trip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        startAddress: startAddress,
        endAddress: endAddress,
        createdAt: DateTime.now(),
        distance: distance,
        duration: duration,
      );

      await _tripService.saveTrip(trip);
      _trips.insert(0, trip);
      _tripMedia[trip.id] = [];
      notifyListeners();
      return trip;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updateTrip(Trip trip) async {
    try {
      await _tripService.saveTrip(trip);
      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index != -1) {
        _trips[index] = trip;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      final mediaFiles = _tripMedia[tripId] ?? [];
      for (var media in mediaFiles) {
        if (media.filePath.isNotEmpty) {
          await _mediaService.deleteFile(media.filePath);
        }
        await _tripService.deleteMediaFile(media.id);
      }

      await _tripService.deleteTrip(tripId);
      _trips.removeWhere((trip) => trip.id == tripId);
      _tripMedia.remove(tripId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<MediaFile?> addMediaToTrip({
    required String tripId,
    required String filePath,
    required MediaType type,
    double? latitude,
    double? longitude,
    String? thumbnailPath,
  }) async {
    try {
      final mediaFile = _mediaService.createMediaFile(
        tripId: tripId,
        filePath: filePath,
        type: type,
        latitude: latitude,
        longitude: longitude,
        thumbnailPath: thumbnailPath,
      );

      await _tripService.saveMediaFile(mediaFile);
      await _tripService.addMediaToTrip(tripId, mediaFile.id);

      if (_tripMedia[tripId] == null) {
        _tripMedia[tripId] = [];
      }
      _tripMedia[tripId]!.insert(0, mediaFile);

      notifyListeners();
      return mediaFile;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> removeMediaFromTrip(String tripId, String mediaId) async {
    try {
      final mediaFiles = _tripMedia[tripId] ?? [];
      final media = mediaFiles.firstWhere((m) => m.id == mediaId);

      if (media.filePath.isNotEmpty) {
        await _mediaService.deleteFile(media.filePath);
      }

      await _tripService.deleteMediaFile(mediaId);
      await _tripService.removeMediaFromTrip(tripId, mediaId);

      _tripMedia[tripId]?.removeWhere((m) => m.id == mediaId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String?> pickAndAddImage(
    String tripId, {
    bool fromCamera = false,
  }) async {
    try {
      final filePath = fromCamera
          ? await _mediaService.captureImage()
          : await _mediaService.pickImageFromGallery();

      if (filePath != null) {
        await addMediaToTrip(
          tripId: tripId,
          filePath: filePath,
          type: MediaType.image,
        );
        return filePath;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> pickAndAddVideo(
    String tripId, {
    bool fromCamera = false,
  }) async {
    try {
      final filePath = fromCamera
          ? await _mediaService.captureVideo()
          : await _mediaService.pickVideoFromGallery();

      if (filePath != null) {
        await addMediaToTrip(
          tripId: tripId,
          filePath: filePath,
          type: MediaType.video,
        );
        return filePath;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> completeTrip(String tripId) async {
    try {
      final trip = getTripById(tripId);
      if (trip != null) {
        trip.completedAt = DateTime.now();
        trip.isActive = false;
        await updateTrip(trip);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
