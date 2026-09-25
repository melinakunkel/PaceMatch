import 'package:flutter/material.dart';

import '../models/activity.dart';
import 'geo.dart';

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

/// Kilometers between the two meeting points, or null when either has no
/// place on the map ("flexibel"). (0, 0) is how a name-only place is
/// stored, so it counts as no place too.
double? meetingDistanceKm(Activity a, Activity b) {
  bool hasPoint(Activity x) =>
      x.latitude != null &&
      x.longitude != null &&
      !(x.latitude == 0 && x.longitude == 0);
  if (!hasPoint(a) || !hasPoint(b)) return null;
  return distanceKm(a.latitude!, a.longitude!, b.latitude!, b.longitude!);
}

/// Whether the two people would travel far enough to meet: each is fine
/// with their own radius around their place, so the areas must touch. No
/// place on either side means "flexibel" — always close enough.
bool closeEnoughToMeet(Activity a, Activity b) {
  final km = meetingDistanceKm(a, b);
  return km == null || km <= a.radiusKm + b.radiusKm;
}

/// Other people's sport times that *almost* fit [mine] — for when there's
/// no real match yet, so the list isn't simply empty.
class NearMissSplit {
  const NearMissSplit({required this.otherDays, required this.otherTimes});

  /// Same sport on another weekday at an overlapping time (weekday → their
  /// activities), so "add this day too" really finds them. Only for a
  /// weekly [mine].
  final Map<int, List<Activity>> otherDays;

  /// Same day, but the times don't overlap.
  final List<Activity> otherTimes;

  bool get isEmpty => otherDays.isEmpty && otherTimes.isEmpty;
}

NearMissSplit splitNearMisses(
  Activity mine,
  List<Activity> others, {
  DateTime? now,
  Set<int> skipDays = const {},
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final otherDays = <int, List<Activity>>{};
  final otherTimes = <Activity>[];
  for (final other in others) {
    if (other.userId == mine.userId) continue;
    if (!closeEnoughToMeet(mine, other)) continue;
    if (other.dayOfWeek == mine.dayOfWeek) {
      if (canMeetOnSameDay(mine, other, now: current) &&
          !_timesOverlap(mine, other)) {
        otherTimes.add(other);
      }
      continue;
    }
    if (!mine.isRecurring || skipDays.contains(other.dayOfWeek)) continue;
    // Adding the day copies my times — only offer it when theirs overlap.
    if (!_timesOverlap(mine, other)) continue;
    final date = _dateOnly(other.specificDate);
    if (date != null && date.isBefore(today)) continue;
    otherDays.putIfAbsent(other.dayOfWeek, () => []).add(other);
  }
  otherTimes.sort(
    (a, b) => _gapMinutes(mine, a).compareTo(_gapMinutes(mine, b)),
  );
  return NearMissSplit(otherDays: otherDays, otherTimes: otherTimes);
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

bool _timesOverlap(Activity a, Activity b) =>
    _minutes(a.startTime) < _minutes(b.endTime) &&
    _minutes(b.startTime) < _minutes(a.endTime);

/// How far apart two non-overlapping time windows are.
int _gapMinutes(Activity mine, Activity other) {
  final gapAfter = _minutes(other.startTime) - _minutes(mine.endTime);
  final gapBefore = _minutes(mine.startTime) - _minutes(other.endTime);
  return gapAfter > 0 ? gapAfter : gapBefore;
}
