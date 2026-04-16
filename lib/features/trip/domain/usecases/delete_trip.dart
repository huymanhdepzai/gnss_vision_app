import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/trip_repository.dart';

class DeleteTrip {
  final TripRepository repository;

  DeleteTrip(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteTrip(id);
  }
}
