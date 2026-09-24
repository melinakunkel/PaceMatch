import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// One GIF from GIPHY: a small still-moving preview for the picker grid and
/// the version that's sent into the chat.
class Gif {
  const Gif({
    required this.id,
    required this.previewUrl,
    required this.url,
    required this.width,
    required this.height,
  });

  final String id;
  final String previewUrl;
  final String url;
  final double width;
  final double height;

  double get aspectRatio => height == 0 ? 1 : width / height;

  /// Parses one entry of GIPHY's `data` array — null when it lacks the
  /// renditions we need.
  static Gif? fromGiphy(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final sent = images?['fixed_width'] as Map<String, dynamic>?;
    final preview =
        (images?['fixed_width_downsampled'] ??
                images?['fixed_width_small'] ??
                sent)
            as Map<String, dynamic>?;
    final url = sent?['url'] as String?;
    final previewUrl = preview?['url'] as String?;
    if (url == null || previewUrl == null) return null;
    return Gif(
      id: json['id'] as String? ?? url,
      previewUrl: previewUrl,
      url: url,
      width: double.tryParse('${sent?['width']}') ?? 200,
      height: double.tryParse('${sent?['height']}') ?? 200,
    );
  }
}

/// GIF search via GIPHY. Needs `GIPHY_API_KEY` in `.env` — without it the
/// GIF button simply doesn't show.
class GiphyService {
  static const _baseUrl = 'https://api.giphy.com/v1/gifs';

  /// Only GIPHY's own media hosts are accepted for sent GIFs (also enforced
  /// by the database), so a chat can't be used to load arbitrary images.
  static final allowedUrl = RegExp(r'^https://media[0-9]*\.giphy\.com/');

  static String get _apiKey {
    try {
      return dotenv.maybeGet('GIPHY_API_KEY') ?? '';
    } catch (_) {
      // .env not loaded (e.g. in tests).
      return '';
    }
  }

  static bool get isEnabled => _apiKey.isNotEmpty;

  /// Trending GIFs when [query] is empty, otherwise search results.
  Future<List<Gif>> search(String query) async {
    if (!isEnabled) return [];
    final trimmed = query.trim();
    final uri =
        Uri.parse(trimmed.isEmpty ? '$_baseUrl/trending' : '$_baseUrl/search')
            .replace(
              queryParameters: {
                'api_key': _apiKey,
                if (trimmed.isNotEmpty) 'q': trimmed,
                'limit': '24',
                // Kinder-Treffs are part of the app — keep it family-friendly.
                'rating': 'pg',
                'lang': 'de',
              },
            );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('GIPHY ${response.statusCode}');
    }
    return parse(response.body);
  }

  static List<Gif> parse(String body) {
    final data = (jsonDecode(body) as Map<String, dynamic>)['data'] as List?;
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) Gif.fromGiphy(entry),
    ].whereType<Gif>().where((g) => allowedUrl.hasMatch(g.url)).toList();
  }
}
