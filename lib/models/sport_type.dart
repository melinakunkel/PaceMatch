import 'package:flutter/material.dart';

enum SportType {
  laufen,
  radfahren,
  schwimmen,
  wandern,
  tennis,
  sonstige;

  static SportType fromDb(String value) => SportType.values.firstWhere(
        (s) => s.name == value,
        orElse: () => SportType.sonstige,
      );

  String get label {
    switch (this) {
      case SportType.laufen:
        return 'Laufen';
      case SportType.radfahren:
        return 'Radfahren';
      case SportType.schwimmen:
        return 'Schwimmen';
      case SportType.wandern:
        return 'Wandern';
      case SportType.tennis:
        return 'Tennis';
      case SportType.sonstige:
        return 'Weitere';
    }
  }

  IconData get icon {
    switch (this) {
      case SportType.laufen:
        return Icons.directions_run;
      case SportType.radfahren:
        return Icons.directions_bike;
      case SportType.schwimmen:
        return Icons.pool;
      case SportType.wandern:
        return Icons.terrain;
      case SportType.tennis:
        return Icons.sports_tennis;
      case SportType.sonstige:
        return Icons.more_horiz;
    }
  }

  /// 'min_per_km' for pace-based sports, 'km_per_h' for speed-based ones.
  String get defaultUnit {
    switch (this) {
      case SportType.radfahren:
        return 'km_per_h';
      default:
        return 'min_per_km';
    }
  }
}
