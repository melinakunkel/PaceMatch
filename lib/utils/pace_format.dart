/// e.g. 5.25 (minutes/km) -> "5:15"
String formatPace(double minutesPerKm) {
  final minutes = minutesPerKm.floor();
  final seconds = ((minutesPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// e.g. 27.0 (km/h) -> "27"
String formatSpeed(double kmh) =>
    kmh == kmh.roundToDouble() ? kmh.toStringAsFixed(0) : kmh.toStringAsFixed(1);
