import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push/push_stub.dart'
    if (dart.library.js_interop) 'push/push_web.dart'
    as impl;
import 'supabase_service.dart';

enum PushEnableResult { enabled, denied, needsHomeScreen, unsupported, failed }

/// Real push notifications on the phone (Web Push), also when SAMEPACE is
/// closed. The browser keeps the subscription; the database knows which
/// account it belongs to (push_subscriptions) and the "push" Edge Function
/// sends to it.
class PushService {
  PushService._();

  /// Which account turned push on for this device — so a different person
  /// logging in on the same browser doesn't silently inherit it.
  static const _ownerKey = 'push_owner_user_id';

  /// Whether this device currently gets push for the logged-in account —
  /// the in-tab notifications stay quiet then, to avoid doubles.
  static final ValueNotifier<bool> active = ValueNotifier(false);

  static bool get isSupported => impl.pushSupported;

  /// iPhone/iPad in a normal Safari tab: push only works after adding
  /// SAMEPACE to the home screen and opening it from there.
  static bool get needsHomeScreen => impl.pushNeedsHomeScreen;

  static String? _publicKey;

  static Future<String> _serverKey() async {
    final cached = _publicKey;
    if (cached != null) return cached;
    final res = await SupabaseService.client.functions.invoke(
      'push',
      body: {'action': 'publicKey'},
    );
    final key = (res.data as Map?)?['publicKey'] as String?;
    if (key == null || key.isEmpty) throw StateError('no push key');
    return _publicKey = key;
  }

  static Future<void> _save(String json) async {
    final sub = jsonDecode(json) as Map<String, dynamic>;
    await SupabaseService.client.rpc(
      'save_push_subscription',
      params: {
        'sub_endpoint': sub['endpoint'],
        'sub_p256dh': sub['p256dh'],
        'sub_auth': sub['auth'],
      },
    );
  }

  /// Call straight from the tap — before any other await — because iOS only
  /// shows the permission prompt in direct response to a tap.
  static Future<PushEnableResult> enable() async {
    if (needsHomeScreen) return PushEnableResult.needsHomeScreen;
    if (!isSupported) return PushEnableResult.unsupported;
    final permission = await impl.requestPushPermission();
    if (permission != 'granted') return PushEnableResult.denied;
    try {
      final json = await impl.subscribePush(await _serverKey());
      if (json == null) return PushEnableResult.failed;
      await _save(json);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ownerKey, SupabaseService.currentUserId ?? '');
      active.value = true;
      return PushEnableResult.enabled;
    } catch (e) {
      debugPrint('push enable failed: $e');
      return PushEnableResult.failed;
    }
  }

  static Future<void> disable() async {
    active.value = false;
    try {
      final endpoint = await impl.unsubscribePush();
      if (endpoint != null) {
        await SupabaseService.client.rpc(
          'delete_push_subscription',
          params: {'sub_endpoint': endpoint},
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ownerKey);
    } catch (e) {
      debugPrint('push disable failed: $e');
    }
  }

  /// After login / app start: re-registers this device's subscription (the
  /// browser may have renewed it) if it was turned on by this account.
  static Future<void> syncAfterLogin() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || !isSupported) {
      active.value = false;
      return;
    }
    try {
      final json = await impl.currentPushSubscription();
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(_ownerKey);
      if (json == null || owner != userId) {
        active.value = false;
        return;
      }
      await _save(json);
      active.value = true;
    } catch (e) {
      debugPrint('push sync failed: $e');
    }
  }

  /// Before logout: stop sending this account's notifications to this
  /// device. The browser keeps its subscription, so logging back in with
  /// the same account turns it on again by itself.
  static Future<void> beforeLogout() async {
    active.value = false;
    try {
      final json = await impl.currentPushSubscription();
      if (json == null) return;
      final endpoint = (jsonDecode(json) as Map)['endpoint'] as String;
      await SupabaseService.client.rpc(
        'delete_push_subscription',
        params: {'sub_endpoint': endpoint},
      );
    } catch (e) {
      debugPrint('push logout cleanup failed: $e');
    }
  }
}
