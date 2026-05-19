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
}
