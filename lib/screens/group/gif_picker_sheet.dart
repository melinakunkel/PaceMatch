import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../services/giphy_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet to search GIPHY and pick one GIF — pops with the [Gif].
class GifPickerSheet extends StatefulWidget {
  const GifPickerSheet({super.key, this.service});

  /// Injectable for tests.
  final GiphyService? service;

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  late final GiphyService _service = widget.service ?? GiphyService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Gif> _gifs = [];
  bool _loading = true;
  bool _failed = false;

  /// Ignores results of a search that was overtaken by a newer one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(query));
  }

  Future<void> _load(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final gifs = await _service.search(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _gifs = gifs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _gifs = [];
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: t('group.gifSearch'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: _onQueryChanged,
                      onSubmitted: _load,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t('common.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildGrid()),
            // Required attribution for using GIPHY's API.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || _gifs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _failed ? t('group.gifLoadFailed') : t('group.gifNoResults'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gif = _gifs[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(gif),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: AppColors.secondaryLight,
              child: GifImage(url: gif.previewUrl, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

/// An animated GIF from GIPHY's CDN. On web, falls back to a plain <img>
/// element if the image can't be fetched directly, so it still animates.
class GifImage extends StatelessWidget {
  const GifImage({super.key, required this.url, this.fit = BoxFit.contain});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (context, error, stack) => Center(
        child: Icon(Icons.gif_box_outlined, color: AppColors.textSecondary),
      ),
    );
  }
}
