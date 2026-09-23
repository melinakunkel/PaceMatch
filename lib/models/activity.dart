import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'sport_type.dart';

/// Not `const` so it always reflects the active language — a top-level
/// getter can still be indexed as `weekdayLabels[i]` exactly like a plain
/// list, so no call site needs to change.
List<String> get weekdayLabels => [
  t('weekday.mo'),
  t('weekday.tu'),
  t('weekday.we'),
  t('weekday.th'),
  t('weekday.fr'),
  t('weekday.sa'),
  t('weekday.su'),
];

List<String> get weekdayFullLabels => [
  t('weekdayFull.mo'),
  t('weekdayFull.tu'),
  t('weekdayFull.we'),
  t('weekdayFull.th'),
  t('weekdayFull.fr'),
  t('weekdayFull.sa'),
  t('weekdayFull.su'),
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

  /// 'normal' / 'longRun' / 'speedRun' — only set for [SportType.laufen].
  final String? runType;

  /// Whether the creator is bringing their own dog — only set for
  /// [SportType.hundeGassi].
  final bool? hasDog;

  /// The child's age/gender — only set for [SportType.kinderSpielen].
  final int? childAge;
  final String? childGender;

  /// Set for a one-off activity on this exact calendar date; null for a
  /// plain weekly recurrence on [dayOfWeek].
  final DateTime? specificDate;

  /// The private "Kreis" this activity belongs to, if any — null means it's
  /// part of the public pool, visible and matchable for everyone.
  final String? circleId;

  /// 'open' (shown in "Entdecken", directly contactable — the default),
  /// 'hidden' (not shown there at all) or 'request' (shown, but contacting
  /// first sends a request that must be accepted before a chat opens).
  /// Only affects the "Entdecken" screen, never matching.
  final String discoverVisibility;

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
    this.runType,
    this.hasDog,
    this.childAge,
    this.childGender,
    this.specificDate,
    this.circleId,
    this.discoverVisibility = 'open',
  });

  bool get isRecurring => specificDate == null;

  bool get isHiddenFromDiscover => discoverVisibility == 'hidden';
  bool get requiresChatRequest => discoverVisibility == 'request';

  /// The next real calendar date+time this activity happens — the exact
  /// date for a one-off activity, or the next upcoming [dayOfWeek] for a
  /// recurring one. Used to know when a meetup is over and ripe for a
  /// check-in.
  DateTime get nextOccurrence {
    if (specificDate != null) {
      return DateTime(
        specificDate!.year,
        specificDate!.month,
        specificDate!.day,
        startTime.hour,
        startTime.minute,
      );
    }
    final now = DateTime.now();
    var daysUntil = (dayOfWeek - now.weekday) % 7;
    final today = DateTime(now.year, now.month, now.day);
    var occurrence = today
        .add(Duration(days: daysUntil))
        .add(Duration(hours: startTime.hour, minutes: startTime.minute));
    if (daysUntil == 0 && occurrence.isBefore(now)) {
      occurrence = occurrence.add(const Duration(days: 7));
    }
    return occurrence;
  }

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
    runType: map['run_type'] as String?,
    hasDog: map['has_dog'] as bool?,
    childAge: map['child_age'] as int?,
    childGender: map['child_gender'] as String?,
    specificDate: map['specific_date'] == null
        ? null
        : DateTime.parse(map['specific_date'] as String),
    circleId: map['circle_id'] as String?,
    discoverVisibility: map['discover_visibility'] as String? ?? 'open',
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
    'has_venue' => t('newActivity.hasVenueYes'),
    'needs_venue' => t('newActivity.hasVenueNo'),
    _ => null,
  };

  String? get bikeTypeLabel => BikeType.fromDb(bikeType)?.label;
  String? get runTypeLabel => RunType.fromDb(runType)?.label;

  String? get hasDogLabel => switch (hasDog) {
    true => t('newActivity.hasDogYes'),
    false => t('newActivity.hasDogNo'),
    null => null,
  };

  bool get hasVenue => venueStatus == 'has_venue';
  bool get needsVenue => venueStatus == 'needs_venue';

  String get specificDateLabel {
    final d = specificDate!;
    return '${weekdayLabels[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.';
  }
}
