import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/map_marker.dart';
import '../repositories/map_repository.dart';

class AddMarker {
  final MapRepository repository;

  AddMarker(this.repository);

  Future<Either<Failure, MapMarker>> call(MapMarker marker) {
    return repository.addMarker(marker);
  }
}
