import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class GetAllTrips {
  final TripRepository repository;

  GetAllTrips(this.repository);

  Future<Either<Failure, List<Trip>>> call() async {
    return await repository.getAllTrips();
  }
}
