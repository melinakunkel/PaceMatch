import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/sport_type.dart';

void main() {
  test('every sport type has a German label and an icon', () {
    for (final sport in SportType.values) {
      expect(sport.label, isNotEmpty);
      expect(sport.icon, isNotNull);
    }
  });

  test('SportType.fromDb falls back to sonstige for unknown values', () {
    expect(SportType.fromDb('unbekannt'), SportType.sonstige);
    expect(SportType.fromDb('laufen'), SportType.laufen);
  });
}
