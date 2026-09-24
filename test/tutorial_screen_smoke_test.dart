import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/screens/tutorial/tutorial_screen.dart';

/// Advances past the slide-change animation. Not `pumpAndSettle()`: the
/// progress track's running-shoe icon bobs via a continuously repeating
/// AnimationController, which never "settles" and would make
/// `pumpAndSettle()` time out. A single large `pump(duration)` isn't enough
/// either — the page-transition animation needs several smaller frames to
/// actually advance — so step through it in small increments instead.
Future<void> _pumpPastTransition(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Weiter/Los gehts button is visible and advances every slide', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

    expect(find.text('Willkommen bei SAMEPACE'), findsOneWidget);

    // 6 slides total: tap through slides 1-5 via "Weiter", then the last
    // slide's button reads "Los geht's".
    for (var i = 0; i < 5; i++) {
      final button = find.text('Weiter');
      expect(tester.takeException(), isNull);
      expect(button, findsOneWidget);
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await _pumpPastTransition(tester);
    }

    expect(tester.takeException(), isNull);
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
    await _pumpPastTransition(tester);
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
