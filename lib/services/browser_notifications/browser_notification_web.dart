import 'dart:html' as html;

bool get notificationsSupported => html.Notification.supported;

Future<bool> requestNotificationPermission() async {
  if (!notificationsSupported) return false;
  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

/// Only fires while the app is running in this browser tab — real push
/// (app/tab closed) needs a service worker + server push, which isn't part
/// of this.
void showBrowserNotification({required String title, String? body}) {
  if (!notificationsSupported) return;
  if (html.Notification.permission != 'granted') return;
  html.Notification(title, body: body);
}
