import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/utils/matching_preferences.dart';

Profile _profile({
  String? gender,
  String? genderPreference,
  int? age,
  int? ageRangeMin,
  int? ageRangeMax,
}) {
  return Profile(
    id: 'id',
    fullName: 'Test',
    gender: gender,
    genderPreference: genderPreference,
    age: age,
    ageRangeMin: ageRangeMin,
    ageRangeMax: ageRangeMax,
  );
}

void main() {
  group('isAllowedByPreferences', () {
    test('no gender/age preference set: everyone allowed', () {
      final me = _profile();
      final other = _profile(gender: 'männlich', age: 40);
      expect(isAllowedByPreferences(me, other), isTrue);
    });

    test('same_only excludes a different gender', () {
      final me = _profile(gender: 'weiblich', genderPreference: 'same_only');
      final other = _profile(gender: 'männlich');
      expect(isAllowedByPreferences(me, other), isFalse);
    });

    test('same_only allows the same gender', () {
      final me = _profile(gender: 'weiblich', genderPreference: 'same_only');
      final other = _profile(gender: 'weiblich');
      expect(isAllowedByPreferences(me, other), isTrue);
    });

    test(
      'the other person restricting to same_only also excludes a mismatch',
      () {
        final me = _profile(gender: 'weiblich');
        final other = _profile(
          gender: 'männlich',
          genderPreference: 'same_only',
        );
        expect(isAllowedByPreferences(me, other), isFalse);
      },
    );

    test('missing gender on either side never blocks a match', () {
      final me = _profile(genderPreference: 'same_only');
      final other = _profile(gender: 'männlich');
      expect(isAllowedByPreferences(me, other), isTrue);
    });

    test('age below my minimum is excluded', () {
      final me = _profile(ageRangeMin: 25, ageRangeMax: 40);
      final other = _profile(age: 20);
      expect(isAllowedByPreferences(me, other), isFalse);
    });

    test('age above my maximum is excluded', () {
      final me = _profile(ageRangeMin: 25, ageRangeMax: 40);
      final other = _profile(age: 45);
      expect(isAllowedByPreferences(me, other), isFalse);
    });

    test('age within my range is allowed', () {
      final me = _profile(ageRangeMin: 25, ageRangeMax: 40);
      final other = _profile(age: 30);
      expect(isAllowedByPreferences(me, other), isTrue);
    });

    test('missing age on the other side is never excluded by age range', () {
      final me = _profile(ageRangeMin: 25, ageRangeMax: 40);
      final other = _profile();
      expect(isAllowedByPreferences(me, other), isTrue);
    });
  });
}
