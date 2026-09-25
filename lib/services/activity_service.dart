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
    final rows = await query
        .order('day_of_week', ascending: true)
        .order('start_time', ascending: true);
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  /// Every active sport time of [userId], across all "Kreise" — used to
  /// find the sport times two people in a private chat have in common.
  Future<List<Activity>> getActiveActivitiesOf(String userId) async {
    final rows = await _client
        .from('activities')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(100);
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
        .order('start_time', ascending: true)
        .limit(300);
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// A weekly copy of [a] on [dayOfWeek] — "add Saturday too" from the
  /// near-miss suggestions.
  Future<Activity> copyToDay(Activity a, int dayOfWeek) => createActivity(
    userId: a.userId,
    sport: a.sport,
    dayOfWeek: dayOfWeek,
    startTime: a.startTime,
    endTime: a.endTime,
    locationName: a.locationName,
    latitude: a.latitude,
    longitude: a.longitude,
    radiusKm: a.radiusKm,
    distanceMinKm: a.distanceMinKm,
    distanceMaxKm: a.distanceMaxKm,
    paceMin: a.paceMin,
    paceMax: a.paceMax,
    venueStatus: a.venueStatus,
    level: a.level,
    bikeType: a.bikeType,
    runType: a.runType,
    hasDog: a.hasDog,
    childAge: a.childAge,
    childGender: a.childGender,
    circleId: a.circleId,
    discoverVisibility: a.discoverVisibility,
    playersWanted: a.playersWanted,
  );

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
    bool? hasDog,
    int? childAge,
    String? childGender,
    DateTime? specificDate,
    String? circleId,
    String discoverVisibility = 'open',
    int playersWanted = 1,
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
          'has_dog': hasDog,
          'child_age': childAge,
          'child_gender': childGender,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
          'circle_id': circleId,
          'discover_visibility': discoverVisibility,
          // Only sent when used, so saving never depends on the column.
          if (playersWanted > 1) 'players_wanted': playersWanted,
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
    bool? hasDog,
    int? childAge,
    String? childGender,
    DateTime? specificDate,
    String discoverVisibility = 'open',
    int? playersWanted,
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
          'has_dog': hasDog,
          'child_age': childAge,
          'child_gender': childGender,
          'specific_date': specificDate == null
              ? null
              : _formatDate(specificDate),
          'discover_visibility': discoverVisibility,
          'players_wanted': ?playersWanted,
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
