import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

/// Where you live, picked from real places instead of typed freely — so
/// everyone in Vienna is "Wien" (events are matched by exact city name),
/// not "wien", "Vienna" or a typo.
///
/// [onChanged] reports the confirmed city (null when cleared) and whether
/// there's typed text that hasn't been picked from the list yet.
class CityPickerField extends StatefulWidget {
  const CityPickerField({
    super.key,
    this.initialCity,
    required this.onChanged,
    this.geocoding,
  });

  final String? initialCity;
  final void Function(String? city, bool pending) onChanged;

  /// Injectable for tests.
  final GeocodingService? geocoding;

  @override
  State<CityPickerField> createState() => _CityPickerFieldState();
}

class _CityPickerFieldState extends State<CityPickerField> {
  late final _geocoding = widget.geocoding ?? GeocodingService();
  late final _ctrl = TextEditingController(text: widget.initialCity ?? '');
  late String? _selected = widget.initialCity;
  List<CityResult> _results = [];
  bool _searching = false;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _pending => _ctrl.text.trim().isNotEmpty && _selected == null;

  void _onTyped(String text) {
    _selected = null;
    widget.onChanged(null, text.trim().isNotEmpty);
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final id = ++_requestId;
      final results = await _geocoding.searchCities(text);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _pick(CityResult city) {
    _ctrl.text = city.name;
    setState(() {
      _selected = city.name;
      _results = [];
    });
    widget.onChanged(city.name, false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: t('onboarding.step3.city'),
            hintText: t('city.hint'),
            prefixIcon: const Icon(Icons.location_city_outlined),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _selected != null
                ? Icon(Icons.check_circle, color: AppColors.secondary)
                : null,
            errorText: _pending && !_searching && _results.isEmpty
                ? t('city.pickFromList')
                : null,
          ),
          onChanged: _onTyped,
        ),
        if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final c in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(c.name),
                    subtitle: c.region == null ? null : Text(c.region!),
                    onTap: () => _pick(c),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
