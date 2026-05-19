import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/entities/navigation_route.dart';
import '../models/navigation_route_model.dart';

abstract class GoongDirectionsDataSource {
  Future<List<NavigationRoute>> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    bool alternatives = true,
    String? destinationName,
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

class GoongDirectionsDataSourceImpl implements GoongDirectionsDataSource {
  final http.Client _client;

  GoongDirectionsDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<List<NavigationRoute>> getRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String vehicle = 'car',
    bool alternatives = true,
    String? destinationName,
  }) async {
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?'
      'origin=$originLat,$originLng&'
      'destination=$destinationLat,$destinationLng&'
      'vehicle=$vehicle&'
      'alternatives=$alternatives&'
      'api_key=$apiKey',
    );

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw ServerException(
        'Failed to fetch directions: ${response.statusCode}',
      );
    }

    final jsonResponse = jsonDecode(response.body);
    return NavigationRouteModel.fromListJson(
      jsonResponse,
      destinationName: destinationName,
    );
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
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final encodedColor = color.replaceAll('#', '%23');
    
    return 'https://rsapi.goong.io/staticmap/route?'
        'origin=$originLat,$originLng&'
        'destination=$destinationLat,$destinationLng&'
        'width=$width&'
        'height=$height&'
        'vehicle=$vehicle&'
        'type=$type&'
        'color=$encodedColor&'
        'api_key=$apiKey';
  }
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}
