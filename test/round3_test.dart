import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/quiet_window.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/utils/strava.dart';

void main() {
  test('Strava links are cleaned up, anything else is refused', () {
    expect(
      normalizeStravaUrl('strava.com/athletes/12345'),
      'https://strava.com/athletes/12345',
    );
    expect(
      normalizeStravaUrl(' https://www.strava.com/athletes/9 '),
      'https://www.strava.com/athletes/9',
    );
    expect(
      normalizeStravaUrl('https://strava.app.link/abc'),
      'https://strava.app.link/abc',
    );
    expect(normalizeStravaUrl(''), '');
    expect(normalizeStravaUrl('https://evil.example/strava.com'), isNull);
    expect(normalizeStravaUrl('https://www.strava.com'), isNull);
  });

  test('quiet windows round-trip through JSON', () {
    const w = QuietWindow(
      TimeOfDay(hour: 22, minute: 0),
      TimeOfDay(hour: 7, minute: 30),
    );
    expect(w.toJson(), {'start': '22:00', 'end': '07:30'});
    final back = QuietWindow.fromJson(w.toJson())!;
    expect(back.start, w.start);
    expect(back.end, w.end);
    expect(QuietWindow.fromJson({'start': 'x'}), isNull);
  });

  test('default travel distance fits the sport', () {
    expect(SportType.radfahren.defaultRadiusKm, 15);
    expect(SportType.hundeGassi.defaultRadiusKm, 2);
    expect(SportType.laufen.defaultRadiusKm, 5);
  });
}
