/// Builds the two most common "add to calendar" links for a meetup — a
/// Google Calendar prefilled-event URL, and a `data:` URI carrying a
/// standard .ics file for every other calendar app (Apple Calendar,
/// Outlook, ...). Both are launched with url_launcher; no file download or
/// platform-specific code needed.
library;

String _formatUtc(DateTime d) {
  final utc = d.toUtc();
  String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}${pad(utc.month)}${pad(utc.day)}'
      'T${pad(utc.hour)}${pad(utc.minute)}${pad(utc.second)}Z';
}

String _escapeIcsText(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

String buildGoogleCalendarUrl({
  required String title,
  required DateTime start,
  required DateTime end,
  String? location,
  String? description,
}) {
  final params = <String, String>{
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${_formatUtc(start)}/${_formatUtc(end)}',
    if (location != null && location.isNotEmpty) 'location': location,
    if (description != null && description.isNotEmpty) 'details': description,
  };
  final query = params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
  return 'https://calendar.google.com/calendar/render?$query';
}

/// Raw .ics content — exposed separately so it's easy to unit-test the
/// formatting/escaping without also asserting on the data: URI wrapper.
String buildIcsContent({
  required String title,
  required DateTime start,
  required DateTime end,
  String? location,
  String? description,
}) {
  final uid = '${start.microsecondsSinceEpoch}-samepace@samepace.app';
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//SAMEPACE//DE',
    'BEGIN:VEVENT',
    'UID:$uid',
    'DTSTAMP:${_formatUtc(DateTime.now())}',
    'DTSTART:${_formatUtc(start)}',
    'DTEND:${_formatUtc(end)}',
    'SUMMARY:${_escapeIcsText(title)}',
    if (location != null && location.isNotEmpty)
      'LOCATION:${_escapeIcsText(location)}',
    if (description != null && description.isNotEmpty)
      'DESCRIPTION:${_escapeIcsText(description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return lines.join('\r\n');
}

String buildIcsDataUri({
  required String title,
  required DateTime start,
  required DateTime end,
  String? location,
  String? description,
}) {
  final ics = buildIcsContent(
    title: title,
    start: start,
    end: end,
    location: location,
    description: description,
  );
  return 'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}';
}
