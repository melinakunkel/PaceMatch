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
    final rows = await _client.from('profiles').select().inFilter('id', userIds);
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
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows up immediately everywhere.
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
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
}
