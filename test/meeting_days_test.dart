import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/activity.dart';
import 'package:samepace/models/match_candidate.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/utils/meeting_days.dart';

Activity _activity({
  required int day,
  String userId = 'u',
  double? lat,
  double? lng,
  double radius = 3,
  DateTime? date,
  TimeOfDay start = const TimeOfDay(hour: 18, minute: 0),
  TimeOfDay end = const TimeOfDay(hour: 19, minute: 0),
}) => Activity(
  id: 'a',
  userId: userId,
  sport: SportType.laufen,
  dayOfWeek: day,
  startTime: start,
  endTime: end,
  specificDate: date,
  latitude: lat,
  longitude: lng,
  radiusKm: radius,
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

  test('near misses: other weekdays and non-overlapping times', () {
    final mine = _activity(day: 3, userId: 'me');
    final split = splitNearMisses(mine, [
      _activity(day: 6, userId: 'sat1'),
      _activity(day: 6, userId: 'sat2'),
      _activity(day: 3, userId: 'overlap'),
      _activity(
        day: 3,
        userId: 'late',
        start: const TimeOfDay(hour: 20, minute: 0),
        end: const TimeOfDay(hour: 21, minute: 0),
      ),
      _activity(
        day: 3,
        userId: 'early',
        start: const TimeOfDay(hour: 16, minute: 30),
        end: const TimeOfDay(hour: 17, minute: 30),
      ),
      _activity(day: 5, userId: 'past', date: DateTime(2026, 9, 18)),
    ], now: now);
    expect(split.otherDays.keys, [6]);
    expect(split.otherDays[6]!.map((a) => a.userId), ['sat1', 'sat2']);
    // Real matches aren't near misses; closest time first.
    expect(split.otherTimes.map((a) => a.userId), ['early', 'late']);
  });

  test('a one-off only gets other-time suggestions, not other days', () {
    final mine = _activity(day: 3, userId: 'me', date: DateTime(2026, 9, 23));
    final split = splitNearMisses(mine, [
      _activity(day: 6, userId: 'sat'),
    ], now: now);
    expect(split.isEmpty, isTrue);
  });

  test('too far apart is not a match; no place counts as flexible', () {
    // Meidling vs. Floridsdorf: roughly 12 km apart.
    final meidling = _activity(day: 3, lat: 48.1747, lng: 16.3290);
    final floridsdorf = _activity(day: 3, lat: 48.2566, lng: 16.3997);
    final prater = _activity(day: 3, lat: 48.2102, lng: 16.3964);
    expect(closeEnoughToMeet(meidling, floridsdorf), isFalse);
    expect(closeEnoughToMeet(meidling, prater), isTrue);
    expect(closeEnoughToMeet(meidling, _activity(day: 3)), isTrue);
    expect(
      closeEnoughToMeet(meidling, _activity(day: 3, lat: 0, lng: 0)),
      isTrue,
    );
    final wide = _activity(day: 3, lat: 48.2566, lng: 16.3997, radius: 10);
    expect(closeEnoughToMeet(meidling, wide), isTrue);
  });

  test('near misses skip people who are too far away', () {
    final mine = _activity(day: 3, userId: 'me', lat: 48.1747, lng: 16.3290);
    final split = splitNearMisses(mine, [
      _activity(day: 6, userId: 'far', lat: 48.2566, lng: 16.3997),
      _activity(day: 6, userId: 'near', lat: 48.2102, lng: 16.3964),
    ], now: now);
    expect(split.otherDays[6]!.map((a) => a.userId), ['near']);
  });

  test('distance label and team sports', () {
    MatchCandidate at(double? km) => MatchCandidate(
      profile: Profile(id: 'p', fullName: 'Anna'),
      theirActivity: _activity(day: 3),
      matchPercent: 50,
      distanceKm: km,
    );
    expect(at(2.44).distanceLabel, '2,4 km');
    expect(at(0.43).distanceLabel, '400 m');
    expect(at(null).distanceLabel, isNull);
    expect(SportType.beachvolleyball.usesPlayerCount, isTrue);
    expect(SportType.laufen.usesPlayerCount, isFalse);
    expect(_activity(day: 3).playersWanted, 1);
  });
}
