import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class CreateTrip {
  final TripRepository repository;

  CreateTrip(this.repository);

  Future<Either<Failure, Trip>> call(Trip trip) async {
    return await repository.createTrip(trip);
  }
}
