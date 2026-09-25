import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Opens the phone's share sheet (Signal, Telegram, Mail, …). Returns false
/// where the browser has none (most desktop browsers), so the caller can
/// fall back to copying the text.
Future<bool> shareText(String text) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('share')) return false;
  try {
    await navigator.share(web.ShareData(text: text)).toDart;
  } catch (_) {
    // Closing the sheet without picking an app also lands here — that's
    // still a handled share, not a reason to fall back.
  }
  return true;
}
