import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  static Future<void> stopListening() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await SupabaseService.client.removeChannel(channel);
  }
}
