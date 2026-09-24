import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/services/geocoding_service.dart';
import 'package:samepace/utils/display_labels.dart';

void main() {
  test('a named place keeps its name plus the town', () {
    expect(
      shortPlaceName({
        'name': 'Hohe Wand',
        'display_name': 'Hohe Wand, Maiersdorf, Neunkirchen, 2724, Österreich',
        'address': {'natural': 'Hohe Wand', 'village': 'Maiersdorf'},
      }),
      'Hohe Wand, Maiersdorf',
    );
  });

  test('a plain street point becomes street and town', () {
    expect(
      shortPlaceName({
        'name': '',
        'display_name':
            'Prater Hauptallee, Leopoldstadt, Wien, 1020, Österreich',
        'address': {
          'road': 'Prater Hauptallee',
          'city_district': 'Leopoldstadt',
          'city': 'Wien',
        },
      }),
      'Prater Hauptallee, Wien',
    );
  });

  test('without address details it keeps only the first two parts', () {
    expect(
      shortPlaceName({'display_name': 'Waldweg, Gutenstein, Bezirk, AT'}),
      'Waldweg, Gutenstein',
    );
  });

  test('old coordinate names are shown as a map pin', () {
    expect(isCoordinateName('47.80487, 15.97940'), isTrue);
    expect(placeLabel('47.80487, 15.97940'), 'Punkt auf der Karte');
    expect(placeLabel('Prater, Wien'), 'Prater, Wien');
    expect(isCoordinateName('Parkplatz 12, 3.5 km'), isFalse);
  });
}
