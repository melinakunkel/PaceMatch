import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_layout.dart';
import '../models/meetup_review.dart';
import '../models/profile.dart';
import '../models/quiet_window.dart';
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

  /// What lowered my own sub-scores — only ever readable for myself.
  Future<ReviewSummary> getMyReviewSummary() async {
    final json = await _client.rpc('my_review_summary');
    return ReviewSummary.fromJson(
      (json as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> updateProfile(Profile profile) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update(profile.toUpdateMap())
        .eq('id', profile.id);
  }

  /// Separate from [updateProfile] so saving a profile never depends on
  /// this newer column. Empty clears it.
  Future<void> setStravaUrl(String userId, String url) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({'strava_url': url.isEmpty ? null : url})
        .eq('id', userId);
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
        .order('sport', ascending: true);
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
        .update({'matches_seen_at': DateTime.now().toUtc().toIso8601String()})
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
        .update({'paused_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> reactivateAccount(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('profiles').update({'paused_at': null}).eq('id', userId);
  }

  /// The Sportplan's visible hours and list/week view, saved on the
  /// account (see 0044_plan_view_prefs.sql). Null values = never set.
  Future<({int? start, int? end, String? viewMode})> getPlanPrefs(
    String userId,
  ) async {
    final row = await _client
        .from('profiles')
        .select('plan_hour_start, plan_hour_end, plan_view_mode')
        .eq('id', userId)
        .maybeSingle();
    return (
      start: row?['plan_hour_start'] as int?,
      end: row?['plan_hour_end'] as int?,
      viewMode: row?['plan_view_mode'] as String?,
    );
  }

  Future<void> updatePlanPrefs(
    String userId, {
    int? start,
    int? end,
    String? viewMode,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({
          'plan_hour_start': ?start,
          'plan_hour_end': ?end,
          'plan_view_mode': ?viewMode,
        })
        .eq('id', userId);
  }

  /// The push "Ruhezeiten" (quiet hours). Falls back to the older single
  /// window (push_quiet_start/end) while the newer column isn't there yet.
  Future<List<QuietWindow>> getPushQuietWindows(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('push_quiet_windows')
          .eq('id', userId)
          .maybeSingle();
      final list = row?['push_quiet_windows'];
      if (list is List && list.isNotEmpty) {
        return list.map(QuietWindow.fromJson).whereType<QuietWindow>().toList();
      }
    } on PostgrestException {
      // Column not added yet — read the single window below.
    }
    final row = await _client
        .from('profiles')
        .select('push_quiet_start, push_quiet_end')
        .eq('id', userId)
        .maybeSingle();
    final start = QuietWindow.parse(row?['push_quiet_start']);
    final end = QuietWindow.parse(row?['push_quiet_end']);
    return start == null || end == null ? [] : [QuietWindow(start, end)];
  }

  /// Empty turns quiet hours off. The first window is also kept in the
  /// older single-window columns.
  Future<void> setPushQuietWindows(
    String userId,
    List<QuietWindow> windows,
  ) async {
    await SupabaseService.ensureFreshSession();
    final first = windows.isEmpty ? null : windows.first;
    await _client
        .from('profiles')
        .update({
          'push_quiet_windows': windows.map((w) => w.toJson()).toList(),
          'push_quiet_start': first == null
              ? null
              : QuietWindow.hhmm(first.start),
          'push_quiet_end': first == null ? null : QuietWindow.hhmm(first.end),
        })
        .eq('id', userId);
  }

  /// Syncs the Home screen's sport-grid order/visibility across
  /// devices/logins, same as [updateThemeVariant] does for the design.
  Future<HomeLayout> getHomeLayout(String userId) async {
    final row = await _client
        .from('profiles')
        .select('home_sport_order, home_hidden_sports')
        .eq('id', userId)
        .maybeSingle();
    final mySports = (await getUserSports(userId)).map((s) => s.sport).toSet();
    return HomeLayout(
      order: (row?['home_sport_order'] as List?)?.cast<String>() ?? const [],
      hidden: (row?['home_hidden_sports'] as List?)?.cast<String>() ?? const [],
      // In the app's usual sport order, not alphabetical by db name.
      preferred: SportType.selectable.where(mySports.contains).toList(),
    );
  }

  Future<void> updateHomeLayout(String userId, HomeLayout layout) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('profiles')
        .update({
          'home_sport_order': layout.order,
          'home_hidden_sports': layout.hidden,
        })
        .eq('id', userId);
  }

  /// Permanently deletes the caller's account — the auth user and
  /// everything that cascades from it (profile, activities, messages, …).
  /// See delete_own_account() in 0031_pause_and_delete_account.sql.
  Future<void> deleteOwnAccount() async {
    await SupabaseService.ensureFreshSession();
    await _client.rpc('delete_own_account');
  }
}
