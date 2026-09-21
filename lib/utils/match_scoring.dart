import 'package:flutter/material.dart';

/// A 0-99 overlap score between two activities' time windows and pace
/// ranges — pure logic, no I/O, so it's unit-testable on its own.
int matchScore({
  required TimeOfDay myStart,
  required TimeOfDay myEnd,
  required TimeOfDay otherStart,
  required TimeOfDay otherEnd,
  double? myPaceMin,
  double? myPaceMax,
  double? otherPaceMin,
  double? otherPaceMax,
}) {
  final timeScore = _overlapRatio(
    _toMinutes(myStart),
    _toMinutes(myEnd),
    _toMinutes(otherStart),
    _toMinutes(otherEnd),
  );
  if (timeScore == 0) return 0;

  final paceScore = _rangeOverlapRatio(
    myPaceMin,
    myPaceMax,
    otherPaceMin,
    otherPaceMax,
  );

  final combined = timeScore * 0.6 + paceScore * 0.4;
  return (combined * 100).round().clamp(0, 99);
}

int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

double _overlapRatio(int aStart, int aEnd, int bStart, int bEnd) {
  final overlapStart = aStart > bStart ? aStart : bStart;
  final overlapEnd = aEnd < bEnd ? aEnd : bEnd;
  final overlap = overlapEnd - overlapStart;
  if (overlap <= 0) return 0;
  final unionSpan =
      (aEnd > bEnd ? aEnd : bEnd) - (aStart < bStart ? aStart : bStart);
  if (unionSpan <= 0) return 0;
  return overlap / unionSpan;
}

double _rangeOverlapRatio(
  double? aMin,
  double? aMax,
  double? bMin,
  double? bMax,
) {
  if (aMin == null || aMax == null || bMin == null || bMax == null) {
    return 0.7; // neutral score when pace data is missing
  }
  final overlapStart = aMin > bMin ? aMin : bMin;
  final overlapEnd = aMax < bMax ? aMax : bMax;
  final overlap = overlapEnd - overlapStart;
  if (overlap <= 0) return 0.2;
  final unionSpan = (aMax > bMax ? aMax : bMax) - (aMin < bMin ? aMin : bMin);
  if (unionSpan <= 0) return 1;
  return (overlap / unionSpan).clamp(0.2, 1.0);
}
