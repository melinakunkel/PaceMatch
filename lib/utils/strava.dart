/// A pasted Strava profile link, cleaned up to `https://…` — or null when
/// it isn't one (only strava.com and Strava's app share links are
/// accepted, so the button never leads somewhere unexpected). An empty
/// input returns '' (= remove the link).
String? normalizeStravaUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return '';
  if (!text.startsWith('http')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  final allowed =
      host == 'strava.com' ||
      host == 'www.strava.com' ||
      host == 'strava.app.link';
  if (!allowed || uri.path.length < 2) return null;
  return uri.replace(scheme: 'https').toString();
}
