import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/meetup_review.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/theme/app_theme.dart';
import 'package:samepace/widgets/reliability_scores.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('no reviews yet shows a hint instead of 0% bars', (tester) async {
    await tester.pumpWidget(
      _host(
        ReliabilityScores(
          profile: Profile(id: 'a', fullName: 'Anna'),
        ),
      ),
    );
    expect(find.text('Noch keine Bewertungen nach Treffen.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('others see only the two sub-scores', (tester) async {
    await tester.pumpWidget(
      _host(
        ReliabilityScores(
          profile: Profile(
            id: 'a',
            fullName: 'Anna',
            attendanceScore: 90,
            accuracyScore: 77.8,
          ),
        ),
      ),
    );
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('Was nicht gepasst hat'), findsNothing);
  });

  testWidgets('my own profile adds counts and what didn\'t match', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ReliabilityScores(
          profile: Profile(
            id: 'a',
            fullName: 'Anna',
            attendanceScore: 90,
            accuracyScore: 77.8,
          ),
          summary: const ReviewSummary(
            total: 10,
            showedUp: 9,
            ratedDetails: 9,
            detailsMatched: 7,
            mismatches: {ReviewMismatch.pace: 2, ReviewMismatch.punctuality: 1},
          ),
        ),
      ),
    );
    expect(find.text('9 von 10'), findsOneWidget);
    expect(find.text('7 von 9'), findsOneWidget);
    expect(find.text('Was nicht gepasst hat'), findsOneWidget);
    expect(find.text('Pace · 2×'), findsOneWidget);
    expect(find.text('Pünktlichkeit · 1×'), findsOneWidget);
  });

  test('summary parses the database json', () {
    final s = ReviewSummary.fromJson({
      'total': 3,
      'showed_up': 2,
      'rated_details': 2,
      'details_matched': 1,
      'mismatches': {'pace': 1, 'unknown_future_value': 4},
    });
    expect(s.total, 3);
    expect(s.mismatches, {ReviewMismatch.pace: 1});
  });
}
