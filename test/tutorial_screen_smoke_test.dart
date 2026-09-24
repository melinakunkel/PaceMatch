import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/screens/tutorial/tutorial_screen.dart';

void main() {
  testWidgets('Weiter/Los gehts button is visible and advances every slide', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

    expect(find.text('Willkommen bei PaceMatch'), findsOneWidget);

    // 6 slides total: tap through slides 1-5 via "Weiter", then the last
    // slide's button reads "Los geht's".
    for (var i = 0; i < 5; i++) {
      final button = find.text('Weiter');
      expect(tester.takeException(), isNull);
      expect(button, findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    expect(find.text('Profil'), findsWidgets);
    final finalButton = find.text('Los geht\'s');
    expect(finalButton, findsOneWidget);
    expect(finalButton.hitTestable(), findsOneWidget);
  });

  testWidgets('Weiter button stays visible and tappable on a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

    expect(tester.takeException(), isNull);
    final button = find.text('Weiter');
    expect(button, findsOneWidget);
    expect(button.hitTestable(), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mein Sportplan'), findsOneWidget);
  });

  testWidgets(
    'Weiter button stays visible on an extremely short viewport (split-screen)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

      expect(tester.takeException(), isNull);
      final button = find.text('Weiter');
      expect(button, findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
    },
  );
}
