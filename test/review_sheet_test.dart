import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/meetup_review.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/screens/group/review_sheet.dart';
import 'package:samepace/theme/app_theme.dart';

void main() {
  testWidgets('submit stays disabled until everyone is rated, then returns '
      'the reviews with the picked mismatches', (tester) async {
    List<MeetupReview>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<List<MeetupReview>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReviewSheet(
                    members: [
                      Profile(id: 'a', fullName: 'Anna Muster'),
                      Profile(id: 'b', fullName: 'David Beispiel'),
                    ],
                    sport: SportType.laufen,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Anna'), findsOneWidget);

    ElevatedButton submit() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(submit().onPressed, isNull);

    // Anna: showed up, details didn't match (pace + punctuality).
    await tester.tap(find.text('Ja').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nein').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pace'));
    await tester.tap(find.text('Pünktlichkeit'));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull);

    // David: didn't show up. His question row comes after Anna's.
    await tester.tap(find.text('Nein').last);
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNotNull);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(result, hasLength(2));
    final anna = result!.firstWhere((r) => r.revieweeId == 'a');
    expect(anna.showedUp, isTrue);
    expect(anna.detailsMatched, isFalse);
    expect(anna.mismatches, {ReviewMismatch.pace, ReviewMismatch.punctuality});
    final david = result!.firstWhere((r) => r.revieweeId == 'b');
    expect(david.showedUp, isFalse);
    expect(
      david.toMap(groupId: 'g', reviewerId: 'me')['details_matched'],
      isNull,
    );
  });
}
