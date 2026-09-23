import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../models/circle_member.dart';
import 'supabase_service.dart';

class CircleService {
  final _client = SupabaseService.client;

  /// The circles [userId] is a member of, newest-joined first.
  Future<List<Circle>> getMyCircles(String userId) async {
    final rows = await _client
        .from('circle_members')
        .select('joined_at, circles(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false)
        .limit(100);
    return rows
        .map((row) => row['circles'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(Circle.fromMap)
        .toList();
  }

  /// Creates a circle and adds the creator as its first member, with admin
  /// rights so they can manage it right away.
  Future<Circle> createCircle({
    required String name,
    String? description,
    required String createdBy,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('circles')
        .insert({
          'name': name,
          'description': description?.trim().isEmpty ?? true
              ? null
              : description!.trim(),
          'created_by': createdBy,
        })
        .select()
        .single();
    final circle = Circle.fromMap(map);
    await _client.from('circle_members').insert({
      'circle_id': circle.id,
      'user_id': createdBy,
      'role': 'admin',
    });
    return circle;
  }

  /// Renames/redescribes a circle — only an admin's RLS policy allows this.
  Future<void> updateCircle({
    required String circleId,
    required String name,
    String? description,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('circles')
        .update({
          'name': name,
          'description': description?.trim().isEmpty ?? true
              ? null
              : description!.trim(),
        })
        .eq('id', circleId);
  }

  /// Joins a circle by its invite code, via a security-definer function so
  /// the client never needs read access to circles it isn't in yet.
  Future<Circle> joinByCode(String code) async {
    await SupabaseService.ensureFreshSession();
    try {
      final map = await _client.rpc(
        'join_circle_by_code',
        params: {'code': code.trim()},
      );
      return Circle.fromMap(map as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      if (e.message.contains('invite code not found')) {
        throw Exception('Dieser Einladungscode wurde nicht gefunden.');
      }
      if (e.message.contains('too many attempts')) {
        throw Exception(
          'Zu viele Versuche. Bitte warte ein paar Minuten und versuch es erneut.',
        );
      }
      rethrow;
    }
  }

  /// Everyone in [circleId] with their role, newest-joined first — relies
  /// on the "members viewable by fellow members" RLS policy, so only works
  /// for a circle the caller is themselves a member of.
  Future<List<CircleMember>> getMembers(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('joined_at, role, profiles(*)')
        .eq('circle_id', circleId)
        .order('joined_at', ascending: false)
        .limit(300);
    return rows.map((row) => CircleMember.fromMap(row)).toList();
  }

  Future<void> leaveCircle({
    required String circleId,
    required String userId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  /// An admin removing someone else from the circle — same delete as
  /// [leaveCircle], kept separate so callers can use distinct confirmation
  /// copy for "I'm leaving" vs. "I'm removing this person".
  Future<void> removeMember({
    required String circleId,
    required String userId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  /// Promotes/demotes a member — only an admin's RLS policy allows this.
  Future<void> setMemberRole({
    required String circleId,
    required String userId,
    required bool isAdmin,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('circle_members')
        .update({'role': isAdmin ? 'admin' : 'member'})
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  /// Permanently deletes a circle — only an admin's RLS policy allows this.
  /// Its members are removed along with it; activities that were scoped to
  /// it (activities.circle_id) fall back to public instead of vanishing.
  Future<void> deleteCircle(String circleId) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('circles').delete().eq('id', circleId);
  }
}
