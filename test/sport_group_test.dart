import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/group.dart';
import 'package:samepace/models/profile.dart';
import 'package:samepace/models/sport_type.dart';

SportGroup _group({required bool isDirect, Profile? partner}) => SportGroup(
  id: 'g',
  name: 'Radfahren mit Michael',
  sport: SportType.radfahren,
  createdBy: 'me',
  isDirect: isDirect,
  partner: partner,
);

void main() {
  test('a private chat is titled with the other person\'s first name', () {
    final g = _group(
      isDirect: true,
      partner: Profile(id: 'd', fullName: 'David Müller'),
    );
    expect(g.displayName, 'David');
  });

  test('a private chat whose partner left falls back to a neutral title', () {
    expect(_group(isDirect: true).displayName, 'Privater Chat');
  });

  test('a group chat keeps its own name', () {
    final g = _group(isDirect: false);
    expect(g.displayName, 'Radfahren mit Michael');
  });

  test('partner survives copyWith and is_direct is read from the row', () {
    final g = SportGroup.fromMap({
      'id': 'g',
      'name': 'x',
      'sport': 'laufen',
      'created_by': 'me',
      'is_direct': true,
    });
    expect(g.isDirect, isTrue);
    final withPartner = g.copyWith(
      partner: Profile(id: 'm', fullName: 'Melina'),
    );
    expect(withPartner.copyWith(hasUnread: true).displayName, 'Melina');
  });
}
