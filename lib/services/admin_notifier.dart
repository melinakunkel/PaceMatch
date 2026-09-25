import 'dart:async';

import 'package:flutter/widgets.dart';

import 'supabase_service.dart';

/// The admin's "something new came in" dot (Profil tab, settings gear,
/// "Meldungen & Feedback") — anything reported, sent as feedback, or an
/// account paused/deleted since they last opened the admin view. Only polls
/// for admins; everyone else never gets a dot.
class AdminNotifier {
  AdminNotifier._();

  static final ValueNotifier<bool> hasNew = ValueNotifier(false);

  static Timer? _pollTimer;
  static AppLifecycleListener? _lifecycle;

  static Future<void> refresh() async {
    if (SupabaseService.currentUserId == null) {
      hasNew.value = false;
      return;
    }
    try {
      hasNew.value = await SupabaseService.client.rpc('admin_has_new') == true;
    } catch (_) {
      // Leave the previous value on transient errors.
    }
  }

  /// Call after login. Checks once whether this account is an admin and
  /// only then keeps the dot up to date.
  static Future<void> startListening() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || _pollTimer != null) return;
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('is_admin')
          .eq('id', userId)
          .maybeSingle();
      if (row?['is_admin'] != true) return;
    } catch (_) {
      return;
    }
    await refresh();
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
  }

  /// Opening the admin view counts as having seen everything.
  static Future<void> markSeen() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    hasNew.value = false;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'admin_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (_) {}
  }

  static void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    hasNew.value = false;
  }
}
