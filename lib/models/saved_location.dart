import 'picked_location.dart';

/// A user's saved/"favorite" place (e.g. a usual running loop) — lets them
/// skip the map search when picking a location they use often.
class SavedLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory SavedLocation.fromMap(Map<String, dynamic> map) => SavedLocation(
    id: map['id'] as String,
    name: map['name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
  );

  PickedLocation toPickedLocation() =>
      PickedLocation(name: name, latitude: latitude, longitude: longitude);
}
