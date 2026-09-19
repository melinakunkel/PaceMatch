import '../utils/pace_format.dart';
import 'sport_type.dart';

class UserSport {
  final String id;
  final String userId;
  final SportType sport;
  final String? level;
  final String unit; // 'min_per_km' or 'km_per_h'
  final double? valueLow;
  final double? valueHigh;

  UserSport({
    required this.id,
    required this.userId,
    required this.sport,
    this.level,
    required this.unit,
    this.valueLow,
    this.valueHigh,
  });

  factory UserSport.fromMap(Map<String, dynamic> map) => UserSport(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        sport: SportType.fromDb(map['sport'] as String),
        level: map['level'] as String?,
        unit: map['unit'] as String? ?? 'min_per_km',
        valueLow: (map['value_low'] as num?)?.toDouble(),
        valueHigh: (map['value_high'] as num?)?.toDouble(),
      );

  /// e.g. "5:15 - 5:45 /km" or "25 - 28 km/h"
  String get rangeLabel {
    if (valueLow == null || valueHigh == null) return '–';
    if (unit == 'km_per_h') {
      return '${formatSpeed(valueLow!)} - ${formatSpeed(valueHigh!)} km/h';
    }
    return '${formatPace(valueLow!)} - ${formatPace(valueHigh!)} /km';
  }
}
