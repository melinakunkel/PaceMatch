import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/sport_type.dart';
import 'supabase_service.dart';

class ActivityService {
  final _client = SupabaseService.client;

  /// [circleId] scopes the result to one "Kreis" (or, when null, to the
  /// public pool) — the active context from [CircleController].
  Future<List<Activity>> getMyActivities(
    String userId, {
    String? circleId,
  }) async {
    var query = _client
        .from('activities')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true);
    query = circleId == null
        ? query.isFilter('circle_id', null)
        : query.eq('circle_id', circleId);
    final rows = await query.order('day_of_week').order('start_time');
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  /// All other users' active activities for a sport, used for matching.
  /// [circleId] restricts candidates to the same "Kreis" as the activity
  /// being matched (or, when null, to the public pool).
  Future<List<Activity>> getActivitiesForSport({
    required SportType sport,
    required String excludeUserId,
    String? circleId,
  }) async {
    var query = _client
        .from('activities')
        .select()
        .eq('sport', sport.name)
        .eq('is_active', true)
        .neq('user_id', excludeUserId);
    query = circleId == null
        ? query.isFilter('circle_id', null)
        : query.eq('circle_id', circleId);
    final rows = await query.limit(300);
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  /// Every other user's activity that's actually happening on [date]: a
  /// recurring one on that weekday, or a one-off with a matching
  /// specific_date. Used by the "Entdecken" screen. [circleId] scopes it to
  /// the active "Kreis" context (or, when null, the public pool). Excludes
  /// activities set to 'hidden' discoverVisibility — matching (see
  /// [getActivitiesForSport]) is unaffected, since that's a separate,
  /// intentional two-sided flow the owner already opted into.
  Future<List<Activity>> getActivitiesForDate({
    required DateTime date,
    required String excludeUserId,
    String? circleId,
  }) async {
    final dateStr = _formatDate(date);
    var query = _client
        .from('activities')
        .select()
        .eq('day_of_week', date.weekday)
        .eq('is_active', true)
        .neq('discover_visibility', 'hidden')
        .neq('user_id', excludeUserId);
    query = circleId == null
        ? query.isFilter('circle_id', null)
        : query.eq('circle_id', circleId);
    final rows = await query
        .or('specific_date.is.null,specific_date.eq.$dateStr')
        .order('start_time')
        .limit(300);
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
    String? runType,
    DateTime? specificDate,
    String? circleId,
    String discoverVisibility = 'open',
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
          'run_type': runType,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
          'circle_id': circleId,
          'discover_visibility': discoverVisibility,
        })
        .select()
        .single();
    return Activity.fromMap(map);
  }

  Future<Activity> getActivityById(String id) async {
    final map = await _client.from('activities').select().eq('id', id).single();
    return Activity.fromMap(map);
  }

  Future<List<Activity>> getActivitiesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client.from('activities').select().inFilter('id', ids);
    return rows.map((m) => Activity.fromMap(m)).toList();
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
    String? runType,
    DateTime? specificDate,
    String discoverVisibility = 'open',
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
          'run_type': runType,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
          'discover_visibility': discoverVisibility,
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
