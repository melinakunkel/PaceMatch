import 'dart:js_interop';

/// The bridge defined in web/push_helper.js.
@JS('samepacePush')
external _PushHelper? get _helper;

extension type _PushHelper._(JSObject _) implements JSObject {
  external bool supported();
  external bool needsHomeScreen();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSString> subscribe(String publicKey);
  external JSPromise<JSString?> current();
  external JSPromise<JSString?> unsubscribe();
}

bool get pushSupported => _helper?.supported() ?? false;

bool get pushNeedsHomeScreen => _helper?.needsHomeScreen() ?? false;

Future<String> requestPushPermission() async {
  final helper = _helper;
  if (helper == null) return 'unsupported';
  return (await helper.requestPermission().toDart).toDart;
}

/// JSON {endpoint, p256dh, auth} of the new (or existing) subscription.
Future<String?> subscribePush(String publicKey) async {
  final helper = _helper;
  if (helper == null) return null;
  return (await helper.subscribe(publicKey).toDart).toDart;
}

Future<String?> currentPushSubscription() async {
  final helper = _helper;
  if (helper == null) return null;
  return (await helper.current().toDart)?.toDart;
}

/// The endpoint that was removed, or null if there was none.
Future<String?> unsubscribePush() async {
  final helper = _helper;
  if (helper == null) return null;
  return (await helper.unsubscribe().toDart)?.toDart;
}
