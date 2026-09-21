import 'package:flutter/material.dart';

import 'activity.dart';
import 'sport_type.dart';

/// A user-hosted, publicly joinable event — shown in Entdecken alongside
/// curated [CommunityEvent]s, but backed by a real group chat that anyone
/// can join up to [maxParticipants].
class OpenEvent {
  final String id;
  final String hostId;
  final String groupId;
  final String name;
  final SportType sport;
  final String? description;
  final DateTime eventDate;
  final TimeOfDay startTime;
  final TimeOfDay? endTime;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? city;
  final int? maxParticipants;
  final int participantCount;
  final bool joined;
  final DateTime createdAt;

  OpenEvent({
    required this.id,
    required this.hostId,
    required this.groupId,
    required this.name,
    required this.sport,
    this.description,
    required this.eventDate,
    required this.startTime,
    this.endTime,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.city,
    this.maxParticipants,
    this.participantCount = 0,
    this.joined = false,
    required this.createdAt,
  });

  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;
  bool get hasMapLocation => latitude != null && longitude != null;

  String get timeRangeLabel => endTime == null
      ? Activity.formatTime(startTime)
      : '${Activity.formatTime(startTime)} - ${Activity.formatTime(endTime!)}';

  String get dateLabel =>
      '${weekdayLabels[eventDate.weekday - 1]}, ${eventDate.day.toString().padLeft(2, '0')}.'
      '${eventDate.month.toString().padLeft(2, '0')}.';

  factory OpenEvent.fromMap(
    Map<String, dynamic> map, {
    int participantCount = 0,
    bool joined = false,
  }) => OpenEvent(
    id: map['id'] as String,
    hostId: map['host_id'] as String,
    groupId: map['group_id'] as String,
    name: map['name'] as String,
    sport: SportType.fromDb(map['sport'] as String),
    description: map['description'] as String?,
    eventDate: DateTime.parse(map['event_date'] as String),
    startTime: _parseTime(map['start_time'] as String),
    endTime: map['end_time'] == null
        ? null
        : _parseTime(map['end_time'] as String),
    locationName: map['location_name'] as String,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    city: map['city'] as String?,
    maxParticipants: map['max_participants'] as int?,
    participantCount: participantCount,
    joined: joined,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
