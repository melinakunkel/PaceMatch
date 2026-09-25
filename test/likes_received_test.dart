import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/activity.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/screens/matches/likes_received_sheet.dart';

void main() {
  testWidgets('who liked you lists people with their sport time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LikesReceivedSheet(
            myActivities: const [],
            likes: [
              PendingLike(
                profile: Profile(id: 'b', fullName: 'Ben Test'),
                activity: Activity(
                  id: 'x',
                  userId: 'b',
                  sport: SportType.laufen,
                  dayOfWeek: 6,
                  startTime: const TimeOfDay(hour: 17, minute: 30),
                  endTime: const TimeOfDay(hour: 18, minute: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Wer hat dich geliked'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.textContaining('Laufen'), findsOneWidget);
    expect(find.text('Auch liken'), findsOneWidget);
  });
}
