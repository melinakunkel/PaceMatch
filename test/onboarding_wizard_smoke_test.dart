import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/screens/onboarding/onboarding_wizard_screen.dart';
import 'package:samepace/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('Weiter button advances through all onboarding steps', (
    tester,
  ) async {
    // Uses the app's real theme, not Flutter's default — the theme's
    // full-width button minimumSize has previously broken layout silently
    // for buttons placed in a Row (see the fix on onboarding's Weiter
    // button), a bug the default MaterialApp theme can't reproduce.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingWizardScreen()),
    );

    expect(find.text('Welche Sportarten machst du?'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Wie fit bist du dabei?'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Ein paar Basisdaten'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Wer soll dir vorgeschlagen werden?'), findsOneWidget);

    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Ein paar Basisdaten'), findsOneWidget);
  });

  testWidgets('Weiter button stays visible and tappable on a short viewport', (
    tester,
  ) async {
    // Simulates a cramped browser window (e.g. split-screen on a laptop) —
    // short enough that a layout overflow would hide the button row.
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingWizardScreen()),
    );

    expect(tester.takeException(), isNull);
    final weiterFinder = find.text('Weiter');
    expect(weiterFinder, findsOneWidget);
    // hitTestable() fails if the widget is off-screen/clipped/obscured —
    // exactly what "no Weiter button to click" would look like.
    expect(find.text('Weiter').hitTestable(), findsOneWidget);

    await tester.tap(weiterFinder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wie fit bist du dabei?'), findsOneWidget);
  });

  testWidgets('each chosen sport gets its own card: Wandern no pace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingWizardScreen()),
    );
    await tester.tap(find.text('Radfahren'));
    await tester.tap(find.text('Wandern'));
    await tester.pump();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dein Tempo beim Radfahren'), findsOneWidget);
    expect(find.textContaining('Tempo beim Wandern'), findsNothing);
    expect(
      find.text(
        'Beim Wandern zählt nur das Level – ein Tempo brauchst du hier nicht.',
      ),
      findsOneWidget,
    );
    expect(find.text('Level'), findsNWidgets(2));
  });
}
