import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/admin_items.dart';
import 'package:samepace/screens/profile/admin_screen.dart';
import 'package:samepace/screens/profile/feedback_sheet.dart';
import 'package:samepace/services/feedback_service.dart';
import 'package:samepace/theme/app_theme.dart';
import 'package:samepace/utils/csv_export.dart';

class _FakeService implements FeedbackService {
  final sent = <(FeedbackCategory, String)>[];
  final statusChanges = <(String, String, bool)>[];

  @override
  Future<void> sendFeedback({
    required FeedbackCategory category,
    required String message,
  }) async => sent.add((category, message));

  @override
  Future<List<ReportItem>> getReports() async => [
    ReportItem(
      id: 'r1',
      reason: 'Belästigung',
      details: 'Hat mir komische Nachrichten geschickt',
      createdAt: DateTime(2026, 9, 25, 18, 5),
      done: false,
      reporterName: 'Anna',
      reportedName: 'Ben',
      reportedCount: 3,
      reportedSuspended: true,
      hasChat: true,
    ),
  ];

  @override
  Future<List<FeedbackItem>> getFeedback() async => [
    FeedbackItem(
      id: 'f1',
      category: FeedbackCategory.idea,
      message: 'Bitte Yoga als Sportart!',
      createdAt: DateTime(2026, 9, 24, 9),
      done: false,
      userName: 'Kai',
    ),
  ];

  @override
  Future<List<AccountFeedbackItem>> getAccountFeedback() async => [
    AccountFeedbackItem(
      id: 'a1',
      isDeletion: true,
      reason: 'Zu wenige Leute in meiner Stadt',
      createdAt: DateTime(2026, 9, 23, 20),
    ),
  ];

  @override
  Future<void> setStatus({
    required String table,
    required String id,
    required bool done,
  }) async => statusChanges.add((table, id, done));
}

void main() {
  test('CSV opens in Excel: semicolons, BOM, quoted text', () {
    final csv = buildCsv(
      ['Datum', 'Nachricht'],
      [
        ['25.09.2026', 'Hallo; "Test"\nzweite Zeile'],
        ['26.09.2026', null],
      ],
    );
    expect(csv.startsWith('﻿Datum;Nachricht\r\n'), isTrue);
    expect(csv, contains('25.09.2026;"Hallo; ""Test""\nzweite Zeile"\r\n'));
    expect(csv, contains('26.09.2026;\r\n'));
  });

  testWidgets('feedback is sent with its category', (tester) async {
    final fake = _FakeService();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FeedbackSheet(service: fake),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fehler'));
    await tester.enterText(find.byType(TextField), 'Karte lädt nicht');
    await tester.pump();
    await tester.tap(find.text('Absenden'));
    await tester.pumpAndSettle();
    expect(fake.sent, [(FeedbackCategory.bug, 'Karte lädt nicht')]);
    expect(result, isTrue);
  });

  testWidgets('admin view lists reports, feedback and account reasons', (
    tester,
  ) async {
    final fake = _FakeService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminScreen(service: fake),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meldungen (1)'), findsOneWidget);
    expect(find.text('Anna meldet Ben'), findsOneWidget);
    expect(
      find.text(
        '3× gemeldet insgesamt · automatisch gesperrt · Chat gespeichert',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Neu'));
    await tester.pumpAndSettle();
    expect(fake.statusChanges, [('reports', 'r1', true)]);

    await tester.tap(find.text('Feedback (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte Yoga als Sportart!'), findsOneWidget);

    await tester.tap(find.text('Pausiert/Gelöscht'));
    await tester.pumpAndSettle();
    expect(find.text('Zu wenige Leute in meiner Stadt'), findsOneWidget);
    expect(find.text('Gelöschtes Konto'), findsOneWidget);
  });
}
