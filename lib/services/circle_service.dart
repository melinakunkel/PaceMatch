import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import 'supabase_service.dart';

class CircleService {
  final _client = SupabaseService.client;

  /// The circles [userId] is a member of, newest-joined first.
  Future<List<Circle>> getMyCircles(String userId) async {
    final rows = await _client
        .from('circle_members')
        .select('joined_at, circles(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);
    return rows
        .map((row) => row['circles'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(Circle.fromMap)
        .toList();
  }

  /// Creates a circle and adds the creator as its first member.
  Future<Circle> createCircle({
    required String name,
    required String createdBy,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('circles')
        .insert({'name': name, 'created_by': createdBy})
        .select()
        .single();
    final circle = Circle.fromMap(map);
    await _client.from('circle_members').insert({
      'circle_id': circle.id,
      'user_id': createdBy,
    });
    return circle;
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
      rethrow;
    }
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
}
