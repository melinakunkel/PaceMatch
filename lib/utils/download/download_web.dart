import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Saves [content] as a file in the browser (Downloads folder / share sheet
/// on phones).
bool downloadTextFile(String filename, String content, String mimeType) {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
