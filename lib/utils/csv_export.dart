import 'download/download_stub.dart'
    if (dart.library.html) 'download/download_web.dart'
    as impl;

/// Builds a CSV that Excel opens directly in German/Austrian settings:
/// semicolon-separated, UTF-8 with BOM (so umlauts and emoji survive).
String buildCsv(List<String> header, List<List<String?>> rows) {
  String cell(String? v) {
    final s = (v ?? '').replaceAll('\r\n', '\n');
    final needsQuotes = s.contains(';') || s.contains('"') || s.contains('\n');
    return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final lines = [
    header.map(cell).join(';'),
    for (final row in rows) row.map(cell).join(';'),
  ];
  return '﻿${lines.join('\r\n')}\r\n';
}

/// Downloads the CSV in the browser. False where that isn't possible.
bool downloadCsv(
  String filename,
  List<String> header,
  List<List<String?>> rows,
) => impl.downloadTextFile(
  filename,
  buildCsv(header, rows),
  'text/csv;charset=utf-8',
);
