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
      final buddies = await LikeService().getBuddies(userId);
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

  /// Call once after login so a new mutual like updates the dot live.
  static void startListening() {
    if (_channel != null) return;
    _channel = SupabaseService.client
        .channel('buddy-likes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            refresh();
            _maybeNotify(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// The realtime subscription above isn't filtered to my rows, so before
  /// notifying, confirm this like involves me, then check whether it just
  /// completed a mutual connection.
  static Future<void> _maybeNotify(Map<String, dynamic> row) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    final fromUser = row['from_user'] as String?;
    final toUser = row['to_user'] as String?;
    if (fromUser != myId && toUser != myId) return;
    try {
      final buddies = await LikeService().getBuddies(myId);
      if (buddies.isEmpty) return;
      final newest = buddies.first;
      if (DateTime.now().difference(newest.connectedAt) >
          const Duration(seconds: 10)) {
        return; // not a fresh connection, just some other like event
      }
      final profile = await ProfileService().getProfile(newest.userId);
      await BrowserNotificationService.showIfEnabled(
        title: 'Neuer Sportbuddy! 🎉',
        body: '${profile.fullName} und du wollt beide trainieren.',
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
