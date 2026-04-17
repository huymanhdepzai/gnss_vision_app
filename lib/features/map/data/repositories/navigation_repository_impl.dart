import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/goong_directions_data_source.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final GoongDirectionsDataSource _dataSource;

  NavigationRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, NavigationRoute>> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
  }) async {
    try {
      final route = await _dataSource.getRoute(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        vehicle: vehicle,
      );
      return Right(route);
    } catch (e) {
      return Left(
        NetworkFailure(message: 'Không thể lấy đường đi: ${e.toString()}'),
      );
    }
  }
}
