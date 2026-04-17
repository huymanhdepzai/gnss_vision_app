import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/entities/navigation_route.dart';
import '../models/navigation_route_model.dart';

abstract class GoongDirectionsDataSource {
  Future<NavigationRoute> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    String? destinationName,
  });
}

class GoongDirectionsDataSourceImpl implements GoongDirectionsDataSource {
  final http.Client _client;

  GoongDirectionsDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<NavigationRoute> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    String? destinationName,
  }) async {
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?'
      'origin=$originLat,$originLng&'
      'destination=$destinationLat,$destinationLng&'
      'vehicle=$vehicle&'
      'api_key=$apiKey',
    );

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw ServerException(
        'Failed to fetch directions: ${response.statusCode}',
      );
    }

    final jsonResponse = jsonDecode(response.body);
    final route = NavigationRouteModel.fromJson(
      jsonResponse,
      destinationName: destinationName,
    );

    return route;
  }
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}
