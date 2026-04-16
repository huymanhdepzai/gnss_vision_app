import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/trip_model.dart';
import '../models/media_file_model.dart';

abstract class TripLocalDataSource {
  Future<Either<Failure, List<TripModel>>> getAllTrips();

  Future<Either<Failure, TripModel?>> getTripById(String id);

  Future<Either<Failure, void>> saveTrip(TripModel trip);

  Future<Either<Failure, void>> deleteTrip(String id);

  Future<Either<Failure, List<MediaFileModel>>> getMediaFilesForTrip(
    String tripId,
  );

  Future<Either<Failure, void>> saveMediaFile(MediaFileModel mediaFile);

  Future<Either<Failure, void>> deleteMediaFile(String mediaId);

  Future<Either<Failure, void>> addMediaToTrip(String tripId, String mediaId);

  Future<Either<Failure, void>> removeMediaFromTrip(
    String tripId,
    String mediaId,
  );
}
