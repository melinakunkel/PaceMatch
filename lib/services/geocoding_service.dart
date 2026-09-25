import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/picked_location.dart';

/// Free-text place search and reverse geocoding via OpenStreetMap's
/// Nominatim API (no API key required).
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  Future<List<PickedLocation>> search(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'format': 'json',
          'q': query,
          'limit': '6',
          'addressdetails': '1',
          'accept-language': 'de',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final results = jsonDecode(response.body) as List;
      return results
          .map(
            (r) => PickedLocation(
              name: shortPlaceName(r as Map<String, dynamic>),
              latitude: double.parse(r['lat'] as String),
              longitude: double.parse(r['lon'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cities/towns matching [query], for picking where you live. Returns
  /// the place's own name (e.g. "Wien") plus region/country to tell apart
  /// places with the same name.
  Future<List<CityResult>> searchCities(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'format': 'json',
          'q': query,
          'featureType': 'settlement',
          'addressdetails': '1',
          'accept-language': 'de',
          'limit': '8',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final results = (jsonDecode(response.body) as List)
          .map((r) => CityResult.fromNominatim(r as Map<String, dynamic>))
          .whereType<CityResult>();
      // Same city can come back several times (city + district etc.).
      final seen = <String>{};
      return [
        for (final c in results)
          if (seen.add('${c.name}|${c.region}')) c,
      ];
    } catch (_) {
      return [];
    }
  }

  /// A short, readable name for a tapped map point ("Hohe Wand, Maiersdorf")
  /// — null when Nominatim can't be reached even after one retry (rate
  /// limiting, connectivity), so the caller can let the user type a name.
  Future<String?> reverseGeocode(double lat, double lon) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      try {
        final uri = Uri.parse('$_baseUrl/reverse').replace(
          queryParameters: {
            'format': 'json',
            'lat': '$lat',
            'lon': '$lon',
            'zoom': '17',
            'addressdetails': '1',
            'accept-language': 'de',
          },
        );
        final response = await http.get(uri);
        if (response.statusCode != 200) continue;
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (result['error'] != null) return null;
        final name = shortPlaceName(result);
        return name.isEmpty ? null : name;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Nominatim's display_name is the whole address chain ("Weg, Ort, Bezirk,
/// Bundesland, PLZ, Österreich") — too long for a meeting point. This keeps
/// the place itself plus its town: "Prater Hauptallee, Wien".
String shortPlaceName(Map<String, dynamic> result) {
  final address = (result['address'] as Map?)?.cast<String, dynamic>() ?? {};
  String? pick(List<String> keys) {
    for (final key in keys) {
      final value = (address[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  final road = pick(['road', 'pedestrian', 'footway', 'path', 'track']);
  final houseNumber = pick(['house_number']);
  final ownName = (result['name'] as String?)?.trim();
  final place = ownName != null && ownName.isNotEmpty
      ? ownName
      : road == null
      ? pick([
          'leisure',
          'amenity',
          'tourism',
          'natural',
          'park',
          'neighbourhood',
          'hamlet',
        ])
      : houseNumber == null
      ? road
      : '$road $houseNumber';
  final town = pick([
    'village',
    'town',
    'city',
    'municipality',
    'suburb',
    'city_district',
    'county',
  ]);

  final parts = <String>[?place, if (town != null && town != place) town];
  if (parts.isNotEmpty) return parts.join(', ');

  final display = (result['display_name'] as String?) ?? '';
  return display.split(',').map((s) => s.trim()).take(2).join(', ');
}

/// A city/town from [GeocodingService.searchCities].
class CityResult {
  const CityResult({required this.name, this.region});

  final String name;

  /// State and country, e.g. "Wien, Österreich" — only for telling apart
  /// places with the same name.
  final String? region;

  static CityResult? fromNominatim(Map<String, dynamic> r) {
    final address = (r['address'] as Map?)?.cast<String, dynamic>() ?? {};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = (address[k] as String?)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final name =
        pick(['city', 'town', 'village', 'municipality', 'hamlet']) ??
        (r['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final state = pick(['state']);
    final country = pick(['country']);
    final region = [
      if (state != null && state != name) state,
      ?country,
    ].join(', ');
    return CityResult(name: name, region: region.isEmpty ? null : region);
  }
}
