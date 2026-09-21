import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Feature-detected rather than assumed: some browsers (older Safari, some
/// in-app webviews) don't expose the Notification API at all, and touching
/// `web.Notification.permission` there would throw instead of just being
/// unsupported.
bool get notificationsSupported => globalContext.has('Notification');

Future<bool> requestNotificationPermission() async {
  if (!notificationsSupported) return false;
  final permission = await web.Notification.requestPermission().toDart;
  return permission.toDart == 'granted';
}

/// Only fires while the app is running in this browser tab — real push
/// (app/tab closed) needs a service worker + server push, which isn't part
/// of this.
void showBrowserNotification({required String title, String? body}) {
  if (!notificationsSupported) return;
  if (web.Notification.permission != 'granted') return;
  if (body != null) {
    web.Notification(title, web.NotificationOptions(body: body));
  } else {
    web.Notification(title);
  }
}
