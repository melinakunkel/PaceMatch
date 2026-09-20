import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browser_notification_service.dart';
import 'group_service.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

/// App-wide "do I have an unseen match" flag, driving the dot on the
/// Matches tab. A match is a group created from a mutual like (see
/// MatchesScreen); "seen" is tracked per-account via
/// profiles.matches_seen_at so it stays in sync across devices.
class MatchNotifier {
  MatchNotifier._();

  static final ValueNotifier<bool> hasNewMatch = ValueNotifier(false);
  static RealtimeChannel? _channel;

  static Future<void> refresh() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      hasNewMatch.value = false;
      return;
    }
    try {
      final seenAt = await ProfileService().getMatchesSeenAt(userId);
      hasNewMatch.value = await GroupService().hasUnseenMatch(
        userId: userId,
        seenAt: seenAt,
      );
    } catch (_) {
      // Leave the previous value on transient errors.
    }
  }

  /// Call when the user opens the Matches tab.
  static Future<void> markSeen() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    hasNewMatch.value = false;
    try {
      await ProfileService().markMatchesSeen(userId);
    } catch (_) {
      // Transient error — the next refresh() will re-derive the flag.
    }
  }

  /// Call once after login so a new mutual match updates the dot live.
  static void startListening() {
    if (_channel != null) return;
    _channel = SupabaseService.client
        .channel('match-groups')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_members',
          callback: (payload) {
            refresh();
            _maybeNotify(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// The realtime subscription above isn't filtered to my rows, so before
  /// notifying, confirm I was actually the one just added, and that it's a
  /// match-created group (not a regular contact or open event).
  static Future<void> _maybeNotify(Map<String, dynamic> row) async {
    final myId = SupabaseService.currentUserId;
    final userId = row['user_id'] as String?;
    final groupId = row['group_id'] as String?;
    if (myId == null || userId != myId || groupId == null) return;
    try {
      final group = await SupabaseService.client
          .from('groups')
          .select('is_match, name')
          .eq('id', groupId)
          .maybeSingle();
      if (group == null || group['is_match'] != true) return;
      await BrowserNotificationService.showIfEnabled(
        title: "It's a Match! 🎉",
        body: '${group['name']} — sag hallo!',
      );
    } catch (_) {
      // Best-effort — never let a notification failure break match state.
    }
  }

  static Future<void> stopListening() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await SupabaseService.client.removeChannel(channel);
  }
}
