import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/sport_type.dart';
import '../models/user_sport.dart';
import 'supabase_service.dart';

class ProfileService {
  final _client = SupabaseService.client;

  Future<Profile> getProfile(String userId) async {
    final map = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromMap(map);
  }

  Future<void> updateProfile(Profile profile) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update(profile.toUpdateMap())
        .eq('id', profile.id);
  }

  Future<List<Profile>> getProfilesByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select()
        .inFilter('id', userIds);
    return rows.map((m) => Profile.fromMap(m)).toList();
  }

  Future<List<UserSport>> getUserSports(String userId) async {
    final rows = await _client
        .from('user_sports')
        .select()
        .eq('user_id', userId)
        .order('sport');
    return rows.map((m) => UserSport.fromMap(m)).toList();
  }

  /// Each of [userIds]' saved level/pace for [sport], keyed by user id — used
  /// to show a match candidate's level (tennis, wandern) alongside their
  /// activity.
  Future<Map<String, UserSport>> getUserSportsForUsers(
    List<String> userIds,
    SportType sport,
  ) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('user_sports')
        .select()
        .inFilter('user_id', userIds)
        .eq('sport', sport.name);
    return {
      for (final row in rows) row['user_id'] as String: UserSport.fromMap(row),
    };
  }

  Future<void> upsertUserSport({
    required String userId,
    required SportType sport,
    String? level,
    required String unit,
    double? valueLow,
    double? valueHigh,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('user_sports').upsert({
      'user_id': userId,
      'sport': sport.name,
      'level': level,
      'unit': unit,
      'value_low': valueLow,
      'value_high': valueHigh,
    }, onConflict: 'user_id,sport');
  }

  /// Uploads a profile photo to the `avatars` bucket (one file per user,
  /// overwritten on re-upload) and returns its public URL.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    await SupabaseService.ensureFreshSession();
    final path = '$userId/avatar.$fileExtension';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows up immediately everywhere.
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Syncs the chosen design across devices/logins — kept separate from
  /// [updateProfile] so saving other profile fields never overwrites it.
  Future<void> updateThemeVariant(String userId, String variant) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'theme_variant': variant})
        .eq('id', userId);
  }

  Future<String?> getThemeVariant(String userId) async {
    final row = await _client
        .from('profiles')
        .select('theme_variant')
        .eq('id', userId)
        .maybeSingle();
    return row?['theme_variant'] as String?;
  }

  /// Syncs the chosen display language across devices/logins, same as
  /// [updateThemeVariant] does for the design.
  Future<void> updateUiLanguage(String userId, String language) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'ui_language': language})
        .eq('id', userId);
  }

  Future<String?> getUiLanguage(String userId) async {
    final row = await _client
        .from('profiles')
        .select('ui_language')
        .eq('id', userId)
        .maybeSingle();
    return row?['ui_language'] as String?;
  }

  /// Persisted server-side (not just local browser storage) so an in-app or
  /// webview browser wiping local storage between sessions doesn't bring the
  /// tutorial back every login.
  Future<bool> getHasSeenTutorial(String userId) async {
    final row = await _client
        .from('profiles')
        .select('has_seen_tutorial')
        .eq('id', userId)
        .maybeSingle();
    return row?['has_seen_tutorial'] as bool? ?? false;
  }

  Future<void> updateHasSeenTutorial(String userId, bool value) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'has_seen_tutorial': value})
        .eq('id', userId);
  }

  /// Recomputes reliability_score from how many past meetups the user
  /// confirmed attending vs. not (see [GroupService.checkIn]), and persists
  /// it. Falls back to the default 100 until they've checked in anywhere.
  Future<double> recomputeReliabilityScore(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('attended')
        .eq('user_id', userId)
        .not('attended', 'is', null);
    if (rows.isEmpty) return 100;
    final total = rows.length;
    final attended = rows.where((r) => r['attended'] == true).length;
    final score = (attended / total * 100).clamp(0, 100).toDouble();
    await _client
        .from('profiles')
        .update({'reliability_score': score})
        .eq('id', userId);
    return score;
  }

  /// When the user last opened the Matches tab — used to know whether a
  /// match-created group is "new" (see [GroupService.hasUnseenMatch]).
  Future<DateTime?> getMatchesSeenAt(String userId) async {
    final row = await _client
        .from('profiles')
        .select('matches_seen_at')
        .eq('id', userId)
        .maybeSingle();
    final raw = row?['matches_seen_at'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  Future<void> markMatchesSeen(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'matches_seen_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// % of the last 7 days the user had an active (checked-in) session.
  Future<List<bool>> getActivityLast7Days(String userId) async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final rows = await _client
        .from('group_members')
        .select('attended, joined_at')
        .eq('user_id', userId)
        .gte('joined_at', since.toIso8601String());
    final byDay = List<bool>.filled(7, false);
    for (final row in rows) {
      final joined = DateTime.parse(row['joined_at'] as String);
      final diff = DateTime.now().difference(joined).inDays;
      if (diff >= 0 && diff < 7) {
        byDay[6 - diff] = true;
      }
    }
    return byDay;
  }

  /// Hides the account from matching/discovery without deleting anything —
  /// reversed automatically the next time this person logs in (see
  /// [reactivateAccount] and the login flow that calls it).
  Future<void> pauseAccount(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'paused_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> reactivateAccount(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('profiles').update({'paused_at': null}).eq('id', userId);
  }

  /// Permanently deletes the caller's account — the auth user and
  /// everything that cascades from it (profile, activities, messages, …).
  /// See delete_own_account() in 0031_pause_and_delete_account.sql.
  Future<void> deleteOwnAccount() async {
    await SupabaseService.ensureFreshSession();
    await _client.rpc('delete_own_account');
  }
}
