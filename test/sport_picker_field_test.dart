import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/sport_type.dart';
import 'package:samepace/theme/app_theme.dart';
import 'package:samepace/widgets/sport_picker_field.dart';

void main() {
  testWidgets('shows the current sport and picks another from the list', (
    tester,
  ) async {
    var sport = SportType.laufen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(16),
              child: SportPickerField(
                value: sport,
                onChanged: (s) => setState(() => sport = s),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Laufen'), findsOneWidget);
    expect(find.text('Badminton'), findsNothing); // no wall of chips

    await tester.tap(find.byType(SportPickerField));
    await tester.pumpAndSettle();
    expect(find.text('Sportart wählen'), findsOneWidget);
    expect(find.text('Weitere'), findsNothing);

    await tester.scrollUntilVisible(find.text('Badminton'), 100);
    await tester.tap(find.text('Badminton'));
    await tester.pumpAndSettle();

    expect(sport, SportType.badminton);
    expect(find.text('Sportart wählen'), findsNothing);
    expect(find.text('Badminton'), findsOneWidget);
  });
}
