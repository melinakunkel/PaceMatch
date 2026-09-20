import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/sport_type.dart';
import 'supabase_service.dart';

class ActivityService {
  final _client = SupabaseService.client;

  Future<List<Activity>> getMyActivities(String userId) async {
    final rows = await _client
        .from('activities')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  /// All other users' active activities for a sport, used for matching.
  Future<List<Activity>> getActivitiesForSport({
    required SportType sport,
    required String excludeUserId,
  }) async {
    final rows = await _client
        .from('activities')
        .select()
        .eq('sport', sport.name)
        .eq('is_active', true)
        .neq('user_id', excludeUserId);
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  /// Every other user's activity that's actually happening on [date]: a
  /// recurring one on that weekday, or a one-off with a matching
  /// specific_date. Used by the "Entdecken" screen.
  Future<List<Activity>> getActivitiesForDate({
    required DateTime date,
    required String excludeUserId,
  }) async {
    final dateStr = _formatDate(date);
    final rows = await _client
        .from('activities')
        .select()
        .eq('day_of_week', date.weekday)
        .eq('is_active', true)
        .neq('user_id', excludeUserId)
        .or('specific_date.is.null,specific_date.eq.$dateStr')
        .order('start_time');
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Activity> createActivity({
    required String userId,
    required SportType sport,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? locationName,
    double? latitude,
    double? longitude,
    double radiusKm = 3,
    double? distanceMinKm,
    double? distanceMaxKm,
    double? paceMin,
    double? paceMax,
    String? venueStatus,
    String? level,
    String? bikeType,
    DateTime? specificDate,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('activities')
        .insert({
          'user_id': userId,
          'sport': sport.name,
          'day_of_week': dayOfWeek,
          'start_time': Activity.formatTime(startTime),
          'end_time': Activity.formatTime(endTime),
          'location_name': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'distance_min_km': distanceMinKm,
          'distance_max_km': distanceMaxKm,
          'pace_min': paceMin,
          'pace_max': paceMax,
          'venue_status': venueStatus,
          'level': level,
          'bike_type': bikeType,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
        })
        .select()
        .single();
    return Activity.fromMap(map);
  }

  Future<Activity> getActivityById(String id) async {
    final map = await _client.from('activities').select().eq('id', id).single();
    return Activity.fromMap(map);
  }

  Future<Activity> updateActivity({
    required String id,
    required SportType sport,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? locationName,
    double? latitude,
    double? longitude,
    double radiusKm = 3,
    double? distanceMinKm,
    double? distanceMaxKm,
    double? paceMin,
    double? paceMax,
    String? venueStatus,
    String? level,
    String? bikeType,
    DateTime? specificDate,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('activities')
        .update({
          'sport': sport.name,
          'day_of_week': dayOfWeek,
          'start_time': Activity.formatTime(startTime),
          'end_time': Activity.formatTime(endTime),
          'location_name': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'distance_min_km': distanceMinKm,
          'distance_max_km': distanceMaxKm,
          'pace_min': paceMin,
          'pace_max': paceMax,
          'venue_status': venueStatus,
          'level': level,
          'bike_type': bikeType,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
        })
        .eq('id', id)
        .select()
        .single();
    return Activity.fromMap(map);
  }

  Future<void> deleteActivity(String id) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('activities').delete().eq('id', id);
  }
}
