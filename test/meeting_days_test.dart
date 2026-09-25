import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/activity.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/utils/meeting_days.dart';

Activity _activity({
  required int day,
  DateTime? date,
  TimeOfDay start = const TimeOfDay(hour: 18, minute: 0),
  TimeOfDay end = const TimeOfDay(hour: 19, minute: 0),
}) => Activity(
  id: 'a',
  userId: 'u',
  sport: SportType.laufen,
  dayOfWeek: day,
  startTime: start,
  endTime: end,
  specificDate: date,
);

void main() {
  // Wednesday 2026-09-23, 17:10.
  final now = DateTime(2026, 9, 23, 17, 10);

  test('spontaneous start rounds up to the next half hour', () {
    expect(spontaneousStart(now), const TimeOfDay(hour: 17, minute: 30));
    expect(
      spontaneousStart(DateTime(2026, 9, 23, 17, 20)),
      const TimeOfDay(hour: 18, minute: 0),
    );
    expect(
      spontaneousStart(DateTime(2026, 9, 23, 23, 40)),
      const TimeOfDay(hour: 22, minute: 30),
    );
    expect(
      oneHourAfter(const TimeOfDay(hour: 23, minute: 30)),
      const TimeOfDay(hour: 23, minute: 59),
    );
  });

  test('weekly activities on the same weekday match', () {
    expect(canMeetOnSameDay(_activity(day: 3), _activity(day: 3)), isTrue);
    expect(canMeetOnSameDay(_activity(day: 3), _activity(day: 4)), isFalse);
  });

  test('two one-offs must be on the same date', () {
    final a = _activity(day: 3, date: DateTime(2026, 9, 30));
    final b = _activity(day: 3, date: DateTime(2026, 10, 7));
    expect(canMeetOnSameDay(a, b, now: now), isFalse);
    expect(canMeetOnSameDay(a, a, now: now), isTrue);
  });

  test('spontaneous today matches weekly plans that are not over yet', () {
    final mine = _activity(day: 3, date: DateTime(2026, 9, 23));
    expect(canMeetOnSameDay(mine, _activity(day: 3), now: now), isTrue);
    final over = _activity(
      day: 3,
      start: const TimeOfDay(hour: 7, minute: 0),
      end: const TimeOfDay(hour: 8, minute: 0),
    );
    expect(canMeetOnSameDay(mine, over, now: now), isFalse);
  });

  test('a past one-off is no longer a match', () {
    final past = _activity(day: 3, date: DateTime(2026, 9, 16));
    expect(canMeetOnSameDay(_activity(day: 3), past, now: now), isFalse);
  });
}
