import 'package:latlong2/latlong.dart';

const _distance = Distance();

/// Great-circle distance between two coordinates, in kilometers.
double distanceKm(double lat1, double lng1, double lat2, double lng2) =>
    _distance.as(LengthUnit.Kilometer, LatLng(lat1, lng1), LatLng(lat2, lng2));
