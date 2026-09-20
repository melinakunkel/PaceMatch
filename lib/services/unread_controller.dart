import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browser_notification_service.dart';
import 'group_service.dart';
import 'supabase_service.dart';

/// App-wide "do I have unread chat messages" flag, driving the dot on the
/// Chat tab. Refreshed on demand (chat list load, opening/leaving a group)
/// and whenever a new message arrives via Realtime.
class UnreadController {
  UnreadController._();

  static final ValueNotifier<bool> hasUnread = ValueNotifier(false);
  static RealtimeChannel? _channel;

  static Future<void> refresh() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      hasUnread.value = false;
      return;
    }
    try {
      hasUnread.value = await GroupService().hasAnyUnread(userId);
    } catch (_) {
      // Leave the previous value on transient errors.
    }
  }

  /// Call once after login so new messages update the dot live without
  /// needing to revisit the chat list.
  static void startListening() {
    if (_channel != null) return;
    _channel = SupabaseService.client
        .channel('unread-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            refresh();
            _maybeNotify(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// The realtime subscription above isn't filtered to my groups, so before
  /// notifying, confirm this message is actually in one of mine (and not
  /// from myself).
  static Future<void> _maybeNotify(Map<String, dynamic> message) async {
    final myId = SupabaseService.currentUserId;
    final senderId = message['sender_id'] as String?;
    final groupId = message['group_id'] as String?;
    if (myId == null || groupId == null || senderId == null) return;
    if (senderId == myId) return;
    try {
      final membership = await SupabaseService.client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('user_id', myId)
          .maybeSingle();
      if (membership == null) return;
      final content = message['content'] as String? ?? '';
      await BrowserNotificationService.showIfEnabled(
        title: 'Neue Nachricht',
        body: content.length > 80 ? '${content.substring(0, 80)}…' : content,
      );
    } catch (_) {
      // Best-effort — never let a notification failure break unread state.
    }
  }

  static Future<void> stopListening() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await SupabaseService.client.removeChannel(channel);
  }
}
