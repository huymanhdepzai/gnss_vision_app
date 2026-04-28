import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchResult {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  const SearchResult({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });
}

class PlaceDetail {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceDetail({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

abstract class GoongSearchDataSource {
  Future<List<SearchResult>> autocomplete(String query, {double? lat, double? lng, double? radius});
  Future<PlaceDetail> getPlaceDetail(String placeId);
}

class GoongSearchDataSourceImpl implements GoongSearchDataSource {
  final http.Client _client;

  GoongSearchDataSourceImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<SearchResult>> autocomplete(String query, {double? lat, double? lng, double? radius}) async {
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final queryParams = {
      'api_key': apiKey,
      'input': query,
      if (lat != null && lng != null) 'location': '$lat,$lng',
      if (radius != null) 'radius': radius.toString(),
    };
    final url = Uri.https('rsapi.goong.io', '/Place/AutoComplete', queryParams);

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw SearchException('Search failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final predictions = json['predictions'] as List<dynamic>? ?? [];
    return predictions.map((item) {
      final structured = item['structured_formatting'] as Map<String, dynamic>?;
      return SearchResult(
        placeId: item['place_id']?.toString() ?? '',
        description: item['description']?.toString() ?? '',
        mainText: structured?['main_text']?.toString(),
        secondaryText: structured?['secondary_text']?.toString(),
      );
    }).toList();
  }

  @override
  Future<PlaceDetail> getPlaceDetail(String placeId) async {
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/Detail?place_id=$placeId&api_key=$apiKey',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw SearchException('Place detail failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final result = json['result'] as Map<String, dynamic>?;
    if (result == null) throw const SearchException('No result in place detail response');

    final location = result['geometry']['location'] as Map<String, dynamic>;
    return PlaceDetail(
      name: result['name']?.toString() ?? '',
      address: result['formatted_address']?.toString() ?? '',
      latitude: location['lat']?.toDouble() ?? 0,
      longitude: location['lng']?.toDouble() ?? 0,
    );
  }
}

class SearchException implements Exception {
  final String message;
  const SearchException(this.message);
  @override
  String toString() => 'SearchException: $message';
}