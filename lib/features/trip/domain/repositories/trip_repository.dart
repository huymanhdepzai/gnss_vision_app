import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/trip.dart';
import '../entities/media_file.dart';

abstract class TripRepository {
  Future<Either<Failure, List<Trip>>> getAllTrips();

  Future<Either<Failure, Trip>> getTripById(String id);

  Future<Either<Failure, Trip>> createTrip(Trip trip);

  Future<Either<Failure, Trip>> updateTrip(Trip trip);

  Future<Either<Failure, void>> deleteTrip(String id);

  Future<Either<Failure, List<MediaFile>>> getMediaForTrip(String tripId);

  Future<Either<Failure, MediaFile>> addMedia(String tripId, String filePath);

  Future<Either<Failure, void>> deleteMedia(String mediaId);
}
