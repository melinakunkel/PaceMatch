import 'package:shared_preferences/shared_preferences.dart';

import 'browser_notifications/browser_notification_stub.dart'
    if (dart.library.html) 'browser_notifications/browser_notification_web.dart'
    as impl;
import 'push_service.dart';

const _prefKey = 'browser_notifications_enabled';

/// Opt-in browser notifications for new messages/matches while the app is
/// open in a tab — not real push (that needs a service worker + server-side
/// push, which is out of scope here), just a foreground nudge so you notice
/// something happened while looking at another tab.
class BrowserNotificationService {
  static bool get isSupported => impl.notificationsSupported;

  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Asks the browser for permission and, if granted, persists the opt-in.
  /// Returns whether it ended up enabled.
  static Future<bool> requestEnable() async {
    if (!isSupported) return false;
    final granted = await impl.requestNotificationPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, granted);
    return granted;
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
  }

  static Future<void> showIfEnabled({
    required String title,
    String? body,
  }) async {
    // Push already shows it (also when the app is closed) — no doubles.
    if (PushService.active.value) return;
    if (!await isEnabled()) return;
    impl.showBrowserNotification(title: title, body: body);
  }
}
