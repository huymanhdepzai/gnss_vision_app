import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/map_marker.dart';

abstract class MapRepository {
  Future<Either<Failure, List<MapMarker>>> getMarkers();

  Future<Either<Failure, MapMarker>> addMarker(MapMarker marker);

  Future<Either<Failure, void>> removeMarker(String id);

  Future<Either<Failure, void>> updateMarker(MapMarker marker);

  Stream<double> get currentLatitude;

  Stream<double> get currentLongitude;

  Stream<double> get currentHeading;
}
