/// Non-web fallback — no Web Push outside the browser.
bool get pushSupported => false;

bool get pushNeedsHomeScreen => false;

Future<String> requestPushPermission() async => 'unsupported';

Future<String?> subscribePush(String publicKey) async => null;

Future<String?> currentPushSubscription() async => null;

Future<String?> unsubscribePush() async => null;
