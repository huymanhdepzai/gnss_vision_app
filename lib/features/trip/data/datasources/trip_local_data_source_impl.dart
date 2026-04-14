import 'package:hive_flutter/hive_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/trip_model.dart';
import '../models/media_file_model.dart';
import 'trip_local_data_source.dart';

class TripLocalDataSourceImpl implements TripLocalDataSource {
  static const String _tripsBoxName = 'trips';
  static const String _mediaBoxName = 'media_files';

  final Box<Map> _tripsBox;
  final Box<Map> _mediaBox;

  TripLocalDataSourceImpl({
    required Box<Map> tripsBox,
    required Box<Map> mediaBox,
  }) : _tripsBox = tripsBox,
       _mediaBox = mediaBox;

  @override
  Future<Either<Failure, List<TripModel>>> getAllTrips() async {
    try {
      final trips = _tripsBox.values.map((dynamic item) {
        final json = Map<String, dynamic>.from(item as Map);
        return TripModel.fromJson(json);
      }).toList();

      trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(trips);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to get trips: $e'));
    }
  }

  @override
  Future<Either<Failure, TripModel?>> getTripById(String id) async {
    try {
      for (var key in _tripsBox.keys) {
        final item = _tripsBox.get(key);
        if (item != null) {
          final json = Map<String, dynamic>.from(item as Map);
          if (json['id'] == id) {
            return Right(TripModel.fromJson(json));
          }
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to get trip: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveTrip(TripModel trip) async {
    try {
      await _tripsBox.put(trip.id, trip.toJson());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to save trip: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTrip(String id) async {
    try {
      await _tripsBox.delete(id);

      final keysToDelete = <dynamic>[];
      for (var key in _mediaBox.keys) {
        final item = _mediaBox.get(key);
        if (item != null) {
          final json = Map<String, dynamic>.from(item as Map);
          if (json['tripId'] == id) {
            keysToDelete.add(key);
          }
        }
      }
      for (var key in keysToDelete) {
        await _mediaBox.delete(key);
      }

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to delete trip: $e'));
    }
  }

  @override
  Future<Either<Failure, List<MediaFileModel>>> getMediaFilesForTrip(
    String tripId,
  ) async {
    try {
      final mediaFiles = <MediaFileModel>[];
      for (var key in _mediaBox.keys) {
        final item = _mediaBox.get(key);
        if (item != null) {
          final json = Map<String, dynamic>.from(item as Map);
          if (json['tripId'] == tripId) {
            mediaFiles.add(MediaFileModel.fromJson(json));
          }
        }
      }

      mediaFiles.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return Right(mediaFiles);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to get media files: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveMediaFile(MediaFileModel mediaFile) async {
    try {
      await _mediaBox.put(mediaFile.id, mediaFile.toJson());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to save media file: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMediaFile(String mediaId) async {
    try {
      await _mediaBox.delete(mediaId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to delete media file: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addMediaToTrip(
    String tripId,
    String mediaId,
  ) async {
    try {
      final result = await getTripById(tripId);
      return result.fold((failure) => Left(failure), (trip) async {
        if (trip != null) {
          final updatedTrip = trip.copyWith(
            mediaFileIds: [...trip.mediaFileIds, mediaId],
          );
          await _tripsBox.put(tripId, updatedTrip.toJson());
        }
        return const Right(null);
      });
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to add media to trip: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeMediaFromTrip(
    String tripId,
    String mediaId,
  ) async {
    try {
      final result = await getTripById(tripId);
      return result.fold((failure) => Left(failure), (trip) async {
        if (trip != null) {
          final updatedMediaIds = trip.mediaFileIds
              .where((id) => id != mediaId)
              .toList();
          final updatedTrip = trip.copyWith(mediaFileIds: updatedMediaIds);
          await _tripsBox.put(tripId, updatedTrip.toJson());
        }
        return const Right(null);
      });
    } catch (e) {
      return Left(
        CacheFailure(message: 'Failed to remove media from trip: $e'),
      );
    }
  }
}
