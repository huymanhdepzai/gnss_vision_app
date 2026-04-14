import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/map_marker.dart';
import '../repositories/map_repository.dart';

class GetMarkers {
  final MapRepository repository;

  GetMarkers(this.repository);

  Future<Either<Failure, List<MapMarker>>> call() {
    return repository.getMarkers();
  }
}
