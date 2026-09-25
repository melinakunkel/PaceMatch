import 'package:flutter/material.dart';

/// One "Ruhezeit" for push notifications, e.g. 22:00–07:00 (may wrap past
/// midnight). Stored in profiles.push_quiet_windows as {"start","end"}.
class QuietWindow {
  const QuietWindow(this.start, this.end);

  final TimeOfDay start;
  final TimeOfDay end;

  static String hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? parse(Object? raw) {
    if (raw is! String || raw.length < 5) return null;
    final hour = int.tryParse(raw.substring(0, 2));
    final minute = int.tryParse(raw.substring(3, 5));
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static QuietWindow? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = parse(json['start']);
    final end = parse(json['end']);
    return start == null || end == null ? null : QuietWindow(start, end);
  }

  Map<String, String> toJson() => {'start': hhmm(start), 'end': hhmm(end)};

  QuietWindow copyWith({TimeOfDay? start, TimeOfDay? end}) =>
      QuietWindow(start ?? this.start, end ?? this.end);
}
