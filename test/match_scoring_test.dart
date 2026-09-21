import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/utils/match_scoring.dart';

void main() {
  group('matchScore', () {
    test('identical time windows and pace ranges score near the top', () {
      final score = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
        myPaceMin: 5,
        myPaceMax: 6,
        otherPaceMin: 5,
        otherPaceMax: 6,
      );
      expect(score, 99);
    });

    test('non-overlapping time windows score zero regardless of pace', () {
      final score = matchScore(
        myStart: const TimeOfDay(hour: 6, minute: 0),
        myEnd: const TimeOfDay(hour: 7, minute: 0),
        otherStart: const TimeOfDay(hour: 20, minute: 0),
        otherEnd: const TimeOfDay(hour: 21, minute: 0),
        myPaceMin: 5,
        myPaceMax: 6,
        otherPaceMin: 5,
        otherPaceMax: 6,
      );
      expect(score, 0);
    });

    test('partial time overlap scores lower than a full overlap', () {
      final full = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
      );
      final partial = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 30),
        otherEnd: const TimeOfDay(hour: 19, minute: 30),
      );
      expect(partial, lessThan(full));
    });

    test('missing pace data on either side falls back to a neutral score', () {
      final withPace = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
        myPaceMin: 5,
        myPaceMax: 6,
        otherPaceMin: 5,
        otherPaceMax: 6,
      );
      final withoutPace = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
      );
      // Same full time overlap, but no pace data means the neutral 0.7
      // pace score instead of a perfect 1.0 — so it should score lower.
      expect(withoutPace, lessThan(withPace));
      expect(withoutPace, greaterThan(0));
    });

    test('disjoint pace ranges score lower than overlapping ones', () {
      final overlapping = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
        myPaceMin: 5,
        myPaceMax: 6,
        otherPaceMin: 5.5,
        otherPaceMax: 6.5,
      );
      final disjoint = matchScore(
        myStart: const TimeOfDay(hour: 18, minute: 0),
        myEnd: const TimeOfDay(hour: 19, minute: 0),
        otherStart: const TimeOfDay(hour: 18, minute: 0),
        otherEnd: const TimeOfDay(hour: 19, minute: 0),
        myPaceMin: 4,
        myPaceMax: 5,
        otherPaceMin: 8,
        otherPaceMax: 9,
      );
      expect(disjoint, lessThan(overlapping));
    });

    test('score never exceeds 99', () {
      final score = matchScore(
        myStart: const TimeOfDay(hour: 0, minute: 0),
        myEnd: const TimeOfDay(hour: 23, minute: 59),
        otherStart: const TimeOfDay(hour: 0, minute: 0),
        otherEnd: const TimeOfDay(hour: 23, minute: 59),
        myPaceMin: 5,
        myPaceMax: 6,
        otherPaceMin: 5,
        otherPaceMax: 6,
      );
      expect(score, lessThanOrEqualTo(99));
    });
  });
}
