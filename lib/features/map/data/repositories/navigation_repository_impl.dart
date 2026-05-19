import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/goong_directions_data_source.dart';
class NavigationRepositoryImpl implements NavigationRepository {
  final GoongDirectionsDataSource _dataSource;

  NavigationRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<NavigationRoute>>> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    bool alternatives = true,
  }) async {
    try {
      final routes = await _dataSource.getRoute(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        vehicle: vehicle,
        alternatives: alternatives,
      );
      return Right(routes);
    } catch (e) {
      return Left(
        NetworkFailure(message: 'Không thể lấy đường đi: ${e.toString()}'),
      );
    }
  }

  @override
  String getStaticMapRouteUrl({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    int width = 600,
    int height = 400,
    String vehicle = 'car',
    String type = 'fastest',
    String color = '#253494',
  }) {
    return _dataSource.getStaticMapRouteUrl(
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      width: width,
      height: height,
      vehicle: vehicle,
      type: type,
      color: color,
    );
  }
}
