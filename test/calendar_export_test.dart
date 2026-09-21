import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/utils/calendar_export.dart';

void main() {
  final start = DateTime.utc(2026, 6, 15, 18, 0);
  final end = DateTime.utc(2026, 6, 15, 19, 0);

  group('buildIcsContent', () {
    test('includes UTC-formatted start/end and required fields', () {
      final ics = buildIcsContent(
        title: 'Laufen mit Anna',
        start: start,
        end: end,
        location: 'Prater',
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics, contains('DTSTART:20260615T180000Z'));
      expect(ics, contains('DTEND:20260615T190000Z'));
      expect(ics, contains('SUMMARY:Laufen mit Anna'));
      expect(ics, contains('LOCATION:Prater'));
    });

    test('escapes commas, semicolons and newlines in text fields', () {
      final ics = buildIcsContent(
        title: 'Lauf, Treffen; Park\nzwei',
        start: start,
        end: end,
      );
      expect(ics, contains('SUMMARY:Lauf\\, Treffen\\; Park\\nzwei'));
    });

    test('omits LOCATION/DESCRIPTION when not given', () {
      final ics = buildIcsContent(title: 'Laufen', start: start, end: end);
      expect(ics, isNot(contains('LOCATION:')));
      expect(ics, isNot(contains('DESCRIPTION:')));
    });
  });

  group('buildGoogleCalendarUrl', () {
    test('builds a calendar.google.com render URL with encoded params', () {
      final url = buildGoogleCalendarUrl(
        title: 'Laufen mit Anna',
        start: start,
        end: end,
        location: 'Prater, Wien',
      );
      expect(url, startsWith('https://calendar.google.com/calendar/render?'));
      expect(url, contains('action=TEMPLATE'));
      expect(url, contains('dates=20260615T180000Z%2F20260615T190000Z'));
      expect(url, contains('text=Laufen'));
      expect(url, contains('location=Prater'));
    });

    test('omits the location param when none is given', () {
      final url = buildGoogleCalendarUrl(
        title: 'Laufen',
        start: start,
        end: end,
      );
      expect(url, isNot(contains('location=')));
    });
  });

  group('buildIcsDataUri', () {
    test('wraps the ics content as a percent-encoded data: URI', () {
      final uri = buildIcsDataUri(title: 'Laufen', start: start, end: end);
      expect(uri, startsWith('data:text/calendar;charset=utf-8,'));
      expect(
        Uri.decodeComponent(uri.substring(uri.indexOf(',') + 1)),
        contains('SUMMARY:Laufen'),
      );
    });
  });
}
