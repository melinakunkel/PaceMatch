import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/screens/group/gif_picker_sheet.dart';
import 'package:samepace/services/giphy_service.dart';
import 'package:samepace/theme/app_theme.dart';

Map<String, dynamic> _entry(String id, {String host = 'media1.giphy.com'}) => {
  'id': id,
  'images': {
    'fixed_width': {
      'url': 'https://$host/media/$id/200w.gif',
      'width': '200',
      'height': '150',
    },
    'fixed_width_downsampled': {'url': 'https://$host/media/$id/200w_d.gif'},
  },
};

class _FakeGiphy implements GiphyService {
  final queries = <String>[];

  @override
  Future<List<Gif>> search(String query) async {
    queries.add(query);
    return [
      Gif.fromGiphy(_entry(query.isEmpty ? 'trend' : query))!,
      Gif.fromGiphy(_entry('two'))!,
    ];
  }
}

void main() {
  test('parses GIPHY results and drops non-GIPHY hosts', () {
    final gifs = GiphyService.parse(
      jsonEncode({
        'data': [
          _entry('a'),
          _entry('evil', host: 'tracker.example.com'),
          {'id': 'broken', 'images': {}},
        ],
      }),
    );
    expect(gifs, hasLength(1));
    expect(gifs.single.url, 'https://media1.giphy.com/media/a/200w.gif');
    expect(gifs.single.previewUrl, endsWith('200w_d.gif'));
    expect(gifs.single.aspectRatio, closeTo(200 / 150, 0.001));
  });

  test('without an API key the GIF button stays hidden', () {
    expect(GiphyService.isEnabled, isFalse);
  });

  testWidgets('shows trending first, searches, and returns the tapped GIF', (
    tester,
  ) async {
    final fake = _FakeGiphy();
    Gif? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<Gif>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => GifPickerSheet(service: fake),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(fake.queries, ['']);
    expect(find.text('Powered by GIPHY'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laufen');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(fake.queries, ['', 'laufen']);

    await tester.tap(find.byType(GifImage).first);
    await tester.pumpAndSettle();
    expect(picked?.url, 'https://media1.giphy.com/media/laufen/200w.gif');
  });
}
