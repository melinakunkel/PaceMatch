import 'activity.dart';
import 'sport_type.dart';

/// A curated, publicly-known event (run club, parkrun, ...) shown in
/// Entdecken with a star — not tied to a user, not a real "match".
class CommunityEvent {
  final String id;
  final String name;
  final String? source;
  final SportType sport;
  final int? dayOfWeek;
  final DateTime? specificDate;
  final String startTime;
  final String? endTime;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String city;
  final String? url;

  CommunityEvent({
    required this.id,
    required this.name,
    this.source,
    required this.sport,
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    this.endTime,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.city,
    this.url,
  });

  factory CommunityEvent.fromMap(Map<String, dynamic> map) => CommunityEvent(
    id: map['id'] as String,
    name: map['name'] as String,
    source: map['source'] as String?,
    sport: SportType.fromDb(map['sport'] as String),
    dayOfWeek: map['day_of_week'] as int?,
    specificDate: map['specific_date'] == null
        ? null
        : DateTime.parse(map['specific_date'] as String),
    startTime: (map['start_time'] as String).substring(0, 5),
    endTime: map['end_time'] == null
        ? null
        : (map['end_time'] as String).substring(0, 5),
    locationName: map['location_name'] as String,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    city: map['city'] as String,
    url: map['url'] as String?,
  );

  String get timeRangeLabel =>
      endTime == null ? startTime : '$startTime - $endTime';
  String get dayLabel =>
      dayOfWeek == null ? '' : weekdayFullLabels[dayOfWeek! - 1];

  /// Every date this event actually happens on between [from] (inclusive)
  /// and [to] (exclusive) — every matching weekday for a recurring event,
  /// or just [specificDate] itself for a one-off, if it falls in range.
  /// Used by the "all events" timeline view to turn a recurring row into
  /// its individual occurrences.
  List<DateTime> occurrencesBetween(DateTime from, DateTime to) {
    if (specificDate != null) {
      final d = DateTime(
        specificDate!.year,
        specificDate!.month,
        specificDate!.day,
      );
      return (!d.isBefore(from) && d.isBefore(to)) ? [d] : [];
    }
    if (dayOfWeek == null) return [];
    final occurrences = <DateTime>[];
    for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 1))) {
      if (d.weekday == dayOfWeek) occurrences.add(d);
    }
    return occurrences;
  }
}
