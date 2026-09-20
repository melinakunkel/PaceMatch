/// e.g. 5.25 (minutes/km) -> "5:15"
String formatPace(double minutesPerKm) {
  final minutes = minutesPerKm.floor();
  final seconds = ((minutesPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// e.g. 27.0 (km/h) -> "27"
String formatSpeed(double kmh) => kmh == kmh.roundToDouble()
    ? kmh.toStringAsFixed(0)
    : kmh.toStringAsFixed(1);

/// The unit suffix shown after a pace/speed value, e.g. "/km", "/100m", "km/h".
String paceUnitSuffix(String unit) {
  switch (unit) {
    case 'km_per_h':
      return 'km/h';
    case 'min_per_100m':
      return '/100m';
    default:
      return '/km';
  }
}

/// The unit label used for section headers, e.g. "min/km", "km/h", "min/100m".
String paceUnitLabel(String unit) {
  switch (unit) {
    case 'km_per_h':
      return 'km/h';
    case 'min_per_100m':
      return 'min/100m';
    default:
      return 'min/km';
  }
}

/// Formats a single value with [formatPace] or [formatSpeed] depending on unit.
String formatPaceOrSpeed(double value, String unit) =>
    unit == 'km_per_h' ? formatSpeed(value) : formatPace(value);

/// e.g. (4.25, 4.75, 'min_per_km') -> "4:15 - 4:45 /km"
String paceRangeLabel(double min, double max, String unit) {
  final suffix = paceUnitSuffix(unit);
  if (unit == 'km_per_h') {
    return '${formatSpeed(min)} - ${formatSpeed(max)} $suffix';
  }
  return '${formatPace(min)} - ${formatPace(max)} $suffix';
}
