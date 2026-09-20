import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/picked_location.dart';

/// Free-text place search and reverse geocoding via OpenStreetMap's
/// Nominatim API (no API key required).
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  Future<List<PickedLocation>> search(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'format': 'json',
        'q': query,
        'limit': '6',
        'addressdetails': '0',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final results = jsonDecode(response.body) as List;
    return results
        .map(
          (r) => PickedLocation(
            name: r['display_name'] as String,
            latitude: double.parse(r['lat'] as String),
            longitude: double.parse(r['lon'] as String),
          ),
        )
        .toList();
  }

  Future<String?> reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {'format': 'json', 'lat': '$lat', 'lon': '$lon'},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return result['display_name'] as String?;
  }
}
