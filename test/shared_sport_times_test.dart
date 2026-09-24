import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/activity.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/utils/shared_sport_times.dart';

Activity _a(
  String id,
  String user,
  SportType sport,
  int day,
  int startHour,
  int endHour, {
  DateTime? date,
  String? place,
}) => Activity(
  id: id,
  userId: user,
  sport: sport,
  dayOfWeek: day,
  startTime: TimeOfDay(hour: startHour, minute: 0),
  endTime: TimeOfDay(hour: endHour, minute: 0),
  specificDate: date,
  locationName: place,
);

void main() {
  final now = DateTime(2026, 9, 24); // a Thursday

  test('finds every overlapping sport time, soonest first', () {
    final mine = [
      _a('m1', 'me', SportType.laufen, 6, 9, 11, place: 'Prater'), // Sat
      _a('m2', 'me', SportType.wandern, 5, 8, 12), // Fri
      _a('m3', 'me', SportType.laufen, 1, 18, 19), // Mon, no partner
    ];
    final theirs = [
      _a('t1', 'max', SportType.laufen, 6, 10, 12),
      _a('t2', 'max', SportType.wandern, 5, 9, 11, place: 'Kahlenberg'),
      _a('t3', 'max', SportType.laufen, 1, 7, 8), // Mon, no time overlap
    ];
    final shared = sharedSportTimes(mine, theirs, now: now);
    expect(shared.map((s) => s.mine.id), ['m2', 'm1']);
    expect(shared.first.locationName, 'Kahlenberg'); // mine has no place
    expect(shared.last.locationName, 'Prater'); // mine wins
    expect(shared.last.involves('t1'), isTrue);
  });

  test('ignores other sports, other days, and one-offs already over', () {
    final mine = [
      _a('m1', 'me', SportType.laufen, 6, 9, 11),
      _a('m2', 'me', SportType.radfahren, 3, 9, 11, date: DateTime(2026, 9, 1)),
    ];
    final theirs = [
      _a('t1', 'max', SportType.radfahren, 6, 9, 11), // other sport
      _a('t2', 'max', SportType.laufen, 5, 9, 11), // other day
      _a('t3', 'max', SportType.radfahren, 3, 9, 11),
    ];
    expect(sharedSportTimes(mine, theirs, now: now), isEmpty);
  });

  test('two one-offs must be on the same date', () {
    final mine = [
      _a('m1', 'me', SportType.laufen, 6, 9, 11, date: DateTime(2026, 9, 26)),
    ];
    final otherDate = [
      _a('t1', 'max', SportType.laufen, 6, 9, 11, date: DateTime(2026, 10, 3)),
    ];
    final sameDate = [
      _a('t2', 'max', SportType.laufen, 6, 9, 11, date: DateTime(2026, 9, 26)),
    ];
    expect(sharedSportTimes(mine, otherDate, now: now), isEmpty);
    expect(sharedSportTimes(mine, sameDate, now: now), hasLength(1));
  });
}
