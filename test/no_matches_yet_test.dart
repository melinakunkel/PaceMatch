import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/activity.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/screens/matches/no_matches_yet.dart';

void main() {
  testWidgets('empty matches show the waiting card and the invite', (
    tester,
  ) async {
    final activity = Activity(
      id: 'a',
      userId: 'u',
      sport: SportType.laufen,
      dayOfWeek: 6,
      startTime: const TimeOfDay(hour: 18, minute: 0),
      endTime: const TimeOfDay(hour: 19, minute: 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoMatchesYet(activity: activity, onDayAdded: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Noch niemand zur gleichen Zeit'), findsOneWidget);
    expect(find.text('Per WhatsApp einladen'), findsOneWidget);
  });
}
