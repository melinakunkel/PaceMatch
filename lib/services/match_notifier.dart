import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browser_notification_service.dart';
import 'like_service.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

/// App-wide "do I have an unseen Sportbuddy" flag, driving the dot on the
/// Sportbuddys tab. A buddy is a mutual like (see MatchesScreen/LikeService);
/// "seen" is tracked per-account via profiles.matches_seen_at so it stays in
/// sync across devices.
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
      final buddies = await LikeService().getBuddies();
      hasNewMatch.value = seenAt == null
          ? buddies.isNotEmpty
          : buddies.any((b) => b.connectedAt.isAfter(seenAt));
    } catch (_) {
      // Leave the previous value on transient errors.
    }
  }

  /// Call when the user opens the Sportbuddys tab.
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
  /// Listens on match_events rather than likes directly — RLS on match_events
  /// only ever delivers rows for a completed mutual match involving this
  /// user, so (unlike the old likes-based subscription) every event received
  /// here is guaranteed to be a real, fresh connection.
  static void startListening() {
    if (_channel != null) return;
    _channel = SupabaseService.client
        .channel('match-events')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'match_events',
          callback: (payload) {
            refresh();
            _maybeNotify(payload.newRecord);
          },
        )
        .subscribe();
  }

  static Future<void> _maybeNotify(Map<String, dynamic> row) async {
    final otherUserId = row['other_user_id'] as String?;
    if (otherUserId == null) return;
    try {
      final profile = await ProfileService().getProfile(otherUserId);
      await BrowserNotificationService.showIfEnabled(
        title: 'Neuer Sportbuddy! 🎉',
        body: '${profile.firstName} und du wollt beide trainieren.',
      );
    } catch (_) {
      // Best-effort — never let a notification failure break buddy state.
    }
  }

  static Future<void> stopListening() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await SupabaseService.client.removeChannel(channel);
  }
}
