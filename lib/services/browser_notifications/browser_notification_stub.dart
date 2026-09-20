/// Non-web fallback — no browser Notification API available.
bool get notificationsSupported => false;

Future<bool> requestNotificationPermission() async => false;

void showBrowserNotification({required String title, String? body}) {}
