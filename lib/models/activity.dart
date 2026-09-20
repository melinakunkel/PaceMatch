import 'package:flutter/material.dart';

import 'sport_type.dart';

const weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const weekdayFullLabels = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

class Activity {
  final String id;
  final String userId;
  final SportType sport;
  final int dayOfWeek; // 1 = Monday .. 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final double? distanceMinKm;
  final double? distanceMaxKm;
  final double? paceMin;
  final double? paceMax;

  /// 'has_venue' (creator already has a court/place) or 'needs_venue'
  /// (still looking for one) — only set for sports where
  /// [SportType.usesVenueQuestion] is true.
  final String? venueStatus;

  /// 'Anfänger' / 'Fortgeschritten' / 'Profi' — only set for sports where
  /// [SportType.usesPace] is false.
  final String? level;

  /// Only set for [SportType.radfahren].
  final String? bikeType;

  /// Set for a one-off activity on this exact calendar date; null for a
  /// plain weekly recurrence on [dayOfWeek].
  final DateTime? specificDate;

  Activity({
    required this.id,
    required this.userId,
    required this.sport,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.locationName,
    this.latitude,
    this.longitude,
    this.radiusKm = 3,
    this.distanceMinKm,
    this.distanceMaxKm,
    this.paceMin,
    this.paceMax,
    this.venueStatus,
    this.level,
    this.bikeType,
    this.specificDate,
  });

  bool get isRecurring => specificDate == null;

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    sport: SportType.fromDb(map['sport'] as String),
    dayOfWeek: map['day_of_week'] as int,
    startTime: _parseTime(map['start_time'] as String),
    endTime: _parseTime(map['end_time'] as String),
    locationName: map['location_name'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    radiusKm: (map['radius_km'] as num?)?.toDouble() ?? 3,
    distanceMinKm: (map['distance_min_km'] as num?)?.toDouble(),
    distanceMaxKm: (map['distance_max_km'] as num?)?.toDouble(),
    paceMin: (map['pace_min'] as num?)?.toDouble(),
    paceMax: (map['pace_max'] as num?)?.toDouble(),
    venueStatus: map['venue_status'] as String?,
    level: map['level'] as String?,
    bikeType: map['bike_type'] as String?,
    specificDate: map['specific_date'] == null
        ? null
        : DateTime.parse(map['specific_date'] as String),
  );

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get timeRangeLabel =>
      '${formatTime(startTime)} - ${formatTime(endTime)}';

  String get dayLabel => weekdayFullLabels[dayOfWeek - 1];
  String get dayShortLabel => weekdayLabels[dayOfWeek - 1];

  String? get venueStatusLabel => switch (venueStatus) {
    'has_venue' => 'Hat schon einen Platz',
    'needs_venue' => 'Sucht noch einen Platz',
    _ => null,
  };

  String? get bikeTypeLabel => BikeType.fromDb(bikeType)?.label;

  bool get hasVenue => venueStatus == 'has_venue';
  bool get needsVenue => venueStatus == 'needs_venue';

  String get specificDateLabel {
    final d = specificDate!;
    return '${weekdayLabels[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.';
  }
}
