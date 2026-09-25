import 'package:flutter/material.dart';

import '../models/activity.dart';

/// Start time for a spontaneous "today" activity: the next full half hour,
/// at least 15 minutes from [now] so there's time to get there. Capped at
/// 22:30 so the default window still fits into the day.
TimeOfDay spontaneousStart(DateTime now) {
  var minutes = now.hour * 60 + now.minute + 15;
  minutes = ((minutes + 29) ~/ 30) * 30;
  if (minutes > 22 * 60 + 30) minutes = 22 * 60 + 30;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

/// [start] plus one hour, but never past 23:59 (activities don't span
/// midnight).
TimeOfDay oneHourAfter(TimeOfDay start) {
  final minutes = start.hour * 60 + start.minute + 60;
  if (minutes >= 24 * 60) return const TimeOfDay(hour: 23, minute: 59);
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

/// Whether [mine] and [other] can actually happen together: same weekday,
/// and if both are one-offs, the same date. A one-off in the past, or one
/// today that's already over, is no longer a match.
bool canMeetOnSameDay(Activity mine, Activity other, {DateTime? now}) {
  if (mine.dayOfWeek != other.dayOfWeek) return false;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);

  final myDate = _dateOnly(mine.specificDate);
  final theirDate = _dateOnly(other.specificDate);
  if (myDate != null && theirDate != null && myDate != theirDate) {
    return false;
  }
  final date = myDate ?? theirDate;
  if (date == null) return true;
  if (date.isBefore(today)) return false;
  if (date == today) {
    final nowMinutes = current.hour * 60 + current.minute;
    final end = other.endTime.hour * 60 + other.endTime.minute;
    if (end <= nowMinutes) return false;
  }
  return true;
}

DateTime? _dateOnly(DateTime? d) =>
    d == null ? null : DateTime(d.year, d.month, d.day);
