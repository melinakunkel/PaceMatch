import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/home_layout.dart';
import 'package:samepace/models/sport_type.dart';

void main() {
  test('every sport in the app exists in the database enum sport_type', () {
    // Saving a sport time with a sport the enum doesn't know fails with
    // "invalid input value for enum sport_type" — catch that here, not
    // when someone creates a Termin.
    final dbValues = <String>{};
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'));
    for (final file in migrations) {
      final sql = file.readAsStringSync();
      final created = RegExp(r"create type sport_type as enum \(([^)]*)\)")
          .firstMatch(sql);
      if (created != null) {
        dbValues.addAll(
          RegExp(r"'([^']+)'").allMatches(created[1]!).map((m) => m[1]!),
        );
      }
      dbValues.addAll(
        RegExp(r"alter type sport_type add value if not exists '([^']+)'")
            .allMatches(sql)
            .map((m) => m[1]!),
      );
    }
    for (final sport in SportType.values) {
      expect(dbValues, contains(sport.name), reason: '${sport.name} missing');
    }
  });

  test('"Weitere" is no longer offered, the new sports are', () {
    expect(SportType.selectable, isNot(contains(SportType.sonstige)));
    expect(
      SportType.selectable,
      containsAll([
        SportType.bouldern,
        SportType.badminton,
        SportType.tischtennis,
        SportType.beachvolleyball,
      ]),
    );
    expect(const HomeLayout().resolve(), isNot(contains(SportType.sonstige)));
    // An old saved home order that still lists "sonstige" doesn't bring it
    // back, and the new sports get appended.
    final layout = const HomeLayout(order: ['sonstige', 'tennis']);
    expect(layout.fullOrder().first, SportType.tennis);
    expect(layout.fullOrder(), contains(SportType.bouldern));
  });

  test('new sports ask for a level, not a pace or distance', () {
    for (final s in [
      SportType.bouldern,
      SportType.badminton,
      SportType.tischtennis,
      SportType.beachvolleyball,
    ]) {
      expect(s.usesPace, isFalse, reason: s.name);
      expect(s.usesDistance, isFalse, reason: s.name);
      expect(s.usesLevel, isTrue, reason: s.name);
    }
  });

  test('court sports ask about a venue, bouldern (walk-in gym) does not', () {
    expect(SportType.badminton.usesVenueQuestion, isTrue);
    expect(SportType.tischtennis.usesVenueQuestion, isTrue);
    expect(SportType.beachvolleyball.usesVenueQuestion, isTrue);
    expect(SportType.bouldern.usesVenueQuestion, isFalse);
  });

  test('existing sports keep their old rules', () {
    expect(SportType.laufen.usesPace, isTrue);
    expect(SportType.radfahren.usesPace, isTrue);
    expect(SportType.schwimmen.usesPace, isTrue);
    expect(SportType.wandern.usesPace, isFalse);
    expect(SportType.wandern.usesDistance, isTrue);
    expect(SportType.tennis.usesPace, isFalse);
    expect(SportType.tennis.usesVenueQuestion, isTrue);
    expect(SportType.padel.usesVenueQuestion, isTrue);
    expect(SportType.hundeGassi.usesLevel, isFalse);
    expect(SportType.kinderSpielen.usesDistance, isFalse);
  });

  test('pick lists are alphabetical', () {
    final labels = SportType.alphabetical.map((s) => s.label).toList();
    expect(labels.first, 'Badminton');
    expect(labels.take(4), [
      'Badminton',
      'Beachvolleyball',
      'Bouldern',
      'Hunde spazieren',
    ]);
    expect(labels.last, 'Wandern');
    expect(SportType.alphabetical, isNot(contains(SportType.sonstige)));
  });
}
