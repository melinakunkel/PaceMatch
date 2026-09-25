import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/services/geocoding_service.dart';
import 'package:samepace/theme/app_theme.dart';
import 'package:samepace/widgets/city_picker_field.dart';

class _FakeGeocoding extends GeocodingService {
  @override
  Future<List<CityResult>> searchCities(String query) async => [
    const CityResult(name: 'Wien', region: 'Österreich'),
    const CityResult(
      name: 'Wiener Neustadt',
      region: 'Niederösterreich, Österreich',
    ),
  ];
}

void main() {
  test('Nominatim results become plain city names', () {
    final wien = CityResult.fromNominatim({
      'name': 'Wien',
      'address': {'city': 'Wien', 'state': 'Wien', 'country': 'Österreich'},
    })!;
    expect(wien.name, 'Wien');
    expect(wien.region, 'Österreich');
    final graz = CityResult.fromNominatim({
      'name': 'Graz',
      'address': {
        'city': 'Graz',
        'state': 'Steiermark',
        'country': 'Österreich',
      },
    })!;
    expect(graz.region, 'Steiermark, Österreich');
  });

  testWidgets('a city must be picked from the list', (tester) async {
    String? city = 'x';
    bool? pending;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CityPickerField(
            geocoding: _FakeGeocoding(),
            onChanged: (c, p) {
              city = c;
              pending = p;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'wien');
    expect(city, isNull);
    expect(pending, isTrue);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Wiener Neustadt'), findsOneWidget);

    await tester.tap(find.text('Wien'));
    await tester.pumpAndSettle();
    expect(city, 'Wien');
    expect(pending, isFalse);
    expect(find.text('Wiener Neustadt'), findsNothing);
  });

  test('the retired "Sport-Date" prompt disappears from profiles', () {
    final p = Profile.fromMap({
      'id': 'a',
      'full_name': 'Melina',
      'prompts': [
        {'q': 'Perfektes Sport-Date für mich...', 'a': 'x'},
        {
          'q': 'Mein Trick, wenn ich keine Lust habe...',
          'a': 'einfach los starten',
        },
      ],
    });
    expect(p.prompts.map((x) => x.question), [
      'Mein Trick, wenn ich keine Lust habe...',
    ]);
  });
}
