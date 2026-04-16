import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_local_data_source.dart';
import '../models/trip_model.dart';
import '../models/media_file_model.dart';

class TripRepositoryImpl implements TripRepository {
  final TripLocalDataSource _localDataSource;

  TripRepositoryImpl({required TripLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, List<Trip>>> getAllTrips() async {
    final result = await _localDataSource.getAllTrips();
    return result.fold(
      (failure) => Left(failure),
      (trips) => Right(trips.map(_mapToEntity).toList()),
    );
  }

  @override
  Future<Either<Failure, Trip>> getTripById(String id) async {
    final result = await _localDataSource.getTripById(id);
    return result.fold(
      (failure) => Left(failure),
      (trip) => trip == null
          ? Left(CacheFailure(message: 'Trip not found'))
          : Right(_mapToEntity(trip)),
    );
  }

  @override
  Future<Either<Failure, Trip>> createTrip(Trip trip) async {
    final model = _mapToModel(trip);
    final result = await _localDataSource.saveTrip(model);
    return result.fold((failure) => Left(failure), (_) => Right(trip));
  }

  @override
  Future<Either<Failure, Trip>> updateTrip(Trip trip) async {
    final model = _mapToModel(trip);
    final result = await _localDataSource.saveTrip(model);
    return result.fold((failure) => Left(failure), (_) => Right(trip));
  }

  @override
  Future<Either<Failure, void>> deleteTrip(String id) async {
    return _localDataSource.deleteTrip(id);
  }

  @override
  Future<Either<Failure, List<MediaFile>>> getMediaForTrip(
    String tripId,
  ) async {
    final result = await _localDataSource.getMediaFilesForTrip(tripId);
    return result.fold(
      (failure) => Left(failure),
      (mediaFiles) => Right(mediaFiles.map(_mapMediaToEntity).toList()),
    );
  }

  @override
  Future<Either<Failure, MediaFile>> addMedia(
    String tripId,
    String filePath,
  ) async {
    final mediaFile = MediaFileModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: tripId,
      filePath: filePath,
      type: MediaType.image,
      capturedAt: DateTime.now(),
    );

    final result = await _localDataSource.saveMediaFile(mediaFile);
    return result.fold((failure) => Left(failure), (_) async {
      await _localDataSource.addMediaToTrip(tripId, mediaFile.id);
      return Right(_mapMediaToEntity(mediaFile));
    });
  }

  @override
  Future<Either<Failure, void>> deleteMedia(String mediaId) async {
    final result = await _localDataSource.deleteMediaFile(mediaId);
    return result;
  }

  Trip _mapToEntity(TripModel model) {
    return Trip(
      id: model.id,
      name: model.title,
      description: model.description,
      createdAt: model.createdAt,
      updatedAt: model.completedAt,
      distance: model.distance,
      duration:
          double.tryParse(model.duration.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0,
      mediaCount: model.mediaFileIds.length,
      isSynced: false,
    );
  }

  TripModel _mapToModel(Trip entity) {
    return TripModel(
      id: entity.id,
      title: entity.name,
      description: entity.description,
      startLat: 0,
      startLng: 0,
      endLat: 0,
      endLng: 0,
      mediaFileIds: [],
      createdAt: entity.createdAt,
      completedAt: entity.updatedAt,
      distance: entity.distance,
      duration: entity.duration.toString(),
      isActive: false,
    );
  }

  MediaFile _mapMediaToEntity(MediaFileModel model) {
    return MediaFile(
      id: model.id,
      tripId: model.tripId,
      path: model.filePath,
      type: model.type == MediaType.image
          ? 'image'
          : model.type == MediaType.video
          ? 'video'
          : 'audio',
      createdAt: model.capturedAt,
      latitude: model.latitude,
      longitude: model.longitude,
      thumbnailPath: model.thumbnailPath,
      duration: model.duration,
      isSynced: model.isSynced,
    );
  }
}
