import 'package:flutter/material.dart';

import '../models/open_event.dart';
import '../models/sport_type.dart';
import 'group_service.dart';
import 'supabase_service.dart';

class OpenEventService {
  final _client = SupabaseService.client;
  final _groupService = GroupService();

  /// Creates the event's group chat, then the event row pointing at it.
  /// The host becomes the first participant automatically (via
  /// [GroupService.createGroup]).
  Future<OpenEvent> createEvent({
    required String hostId,
    required String name,
    required SportType sport,
    String? description,
    required DateTime eventDate,
    required TimeOfDay startTime,
    TimeOfDay? endTime,
    required String locationName,
    double? latitude,
    double? longitude,
    String? city,
    int? maxParticipants,
  }) async {
    await SupabaseService.ensureFreshSession();
    final group = await _groupService.createGroup(
      createdBy: hostId,
      sport: sport,
      name: name,
      meetingPoint: locationName,
      latitude: latitude,
      longitude: longitude,
      meetingTime: DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        startTime.hour,
        startTime.minute,
      ),
    );
    final map = await _client
        .from('open_events')
        .insert({
          'host_id': hostId,
          'group_id': group.id,
          'name': name,
          'sport': sport.name,
          'description': description,
          'event_date': _dateStr(eventDate),
          'start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          'end_time': endTime == null
              ? null
              : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
          'location_name': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'city': city,
          'max_participants': maxParticipants,
        })
        .select()
        .single();
    return OpenEvent.fromMap(map, participantCount: 1, joined: true);
  }

  /// Open events in [city] on [date], with participant counts and whether
  /// [userId] has already joined each one.
  Future<List<OpenEvent>> getForCityAndDate({
    required String city,
    required DateTime date,
    required String userId,
  }) async {
    final rows = await _client
        .from('open_events')
        .select('*, groups(group_members(count))')
        .eq('city', city)
        .eq('event_date', _dateStr(date))
        .order('start_time');
    if (rows.isEmpty) return [];

    final groupIds = rows.map((r) => r['group_id'] as String).toList();
    final myMemberships = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId)
        .inFilter('group_id', groupIds);
    final joinedGroupIds = myMemberships
        .map((r) => r['group_id'] as String)
        .toSet();

    return rows.map((row) {
      final groupData = row['groups'] as Map<String, dynamic>?;
      final countRows = groupData?['group_members'] as List?;
      final count = countRows != null && countRows.isNotEmpty
          ? (countRows.first['count'] as int? ?? 0)
          : 0;
      return OpenEvent.fromMap(
        row,
        participantCount: count,
        joined: joinedGroupIds.contains(row['group_id'] as String),
      );
    }).toList();
  }

  Future<void> joinEvent({required String groupId, required String userId}) =>
      _groupService.joinGroup(groupId: groupId, userId: userId);

  /// Only name/description/maxParticipants are editable — sport, date/time
  /// and location stay fixed once people have joined based on them. Also
  /// renames the event's group chat to match, so the two don't drift apart.
  Future<void> updateEvent({
    required String id,
    required String groupId,
    required String name,
    String? description,
    int? maxParticipants,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('open_events')
        .update({
          'name': name,
          'description': description,
          'max_participants': maxParticipants,
        })
        .eq('id', id);
    await _client.from('groups').update({'name': name}).eq('id', groupId);
  }

  /// Removes the event from Entdecken — the group chat (and anyone already
  /// in it) is left untouched, since people may still want to reach each
  /// other, e.g. to say the event is cancelled.
  Future<void> deleteEvent(String id) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('open_events').delete().eq('id', id);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
