import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/navigation_route.dart';
abstract class NavigationRepository {
  Future<Either<Failure, List<NavigationRoute>>> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    bool alternatives = true,
  });

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
  });
}
