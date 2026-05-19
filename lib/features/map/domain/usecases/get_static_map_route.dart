import '../repositories/navigation_repository.dart';

class GetStaticMapRoute {
  final NavigationRepository repository;

  GetStaticMapRoute(this.repository);

  String call({
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
    return repository.getStaticMapRouteUrl(
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
