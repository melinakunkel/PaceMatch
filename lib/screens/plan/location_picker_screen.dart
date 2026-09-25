import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/strings.dart';
import '../../models/picked_location.dart';
import '../../models/saved_location.dart';
import '../../services/geocoding_service.dart';
import '../../services/saved_location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';

/// Full-screen OpenStreetMap picker: search a place, tap the map to fine-tune
/// the pin, confirm to return a [PickedLocation]. Also offers the user's
/// saved "favorite" locations as a shortcut past the search.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _viennaFallback = LatLng(48.2082, 16.3738);

  final _geocoding = GeocodingService();
  final _savedLocationService = SavedLocationService();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();

  Timer? _debounce;
  List<PickedLocation> _results = [];
  bool _searching = false;

  LatLng? _picked;
  String? _pickedName;

  /// A tapped point's name is still being looked up.
  bool _resolvingName = false;
  bool _saving = false;

  late Future<List<SavedLocation>> _savedFuture = _savedLocationService
      .getSavedLocations();

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _picked = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _pickedName = widget.initial!.name;
      // Old coordinate-only names aren't worth showing — let the user type.
      if (!isCoordinateName(widget.initial!.name)) {
        _searchCtrl.text = widget.initial!.name;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (query.trim().length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final results = await _geocoding.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _selectResult(PickedLocation result) {
    setState(() {
      _picked = LatLng(result.latitude, result.longitude);
      _pickedName = result.name;
      _searchCtrl.text = result.name;
      _results = [];
    });
    _mapController.move(_picked!, 15);
    FocusScope.of(context).unfocus();
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _picked = point;
      _pickedName = null;
      _resolvingName = true;
    });
    final name = await _geocoding.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted || _picked != point) return;
    setState(() {
      _resolvingName = false;
      // No name found: leave the field empty (its hint asks for one) rather
      // than filling it with raw coordinates.
      _pickedName = name;
      _searchCtrl.text = name ?? '';
    });
  }

  Future<void> _saveFavorite() async {
    if (_picked == null || _saving) return;
    final name = _searchCtrl.text.trim().isNotEmpty
        ? _searchCtrl.text.trim()
        : (_pickedName ?? t('location.pinOnMap'));
    setState(() => _saving = true);
    try {
      await _savedLocationService.saveLocation(
        PickedLocation(
          name: name,
          latitude: _picked!.latitude,
          longitude: _picked!.longitude,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savedFuture = _savedLocationService.getSavedLocations();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('locationPicker.favoriteSaved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('locationPicker.favoriteSaveFailed', {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteFavorite(SavedLocation saved) async {
    try {
      await _savedLocationService.deleteSavedLocation(saved.id);
      if (!mounted) return;
      setState(() {
        _savedFuture = _savedLocationService.getSavedLocations();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('locationPicker.favoriteSaveFailed', {'error': '$e'}),
          ),
        ),
      );
    }
  }

  void _confirm() {
    if (_picked == null) return;
    // Prefer whatever's actually in the text field: if reverse geocoding
    // failed (or the user just prefers a different name) they may have
    // typed over the pre-filled value, and that edit was otherwise silently
    // discarded in favor of the stale [_pickedName].
    final typed = _searchCtrl.text.trim();
    Navigator.of(context).pop(
      PickedLocation(
        name: typed.isNotEmpty
            ? typed
            : (_pickedName ?? t('location.pinOnMap')),
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('locationPicker.title')),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked ?? _viennaFallback,
              initialZoom: _picked != null ? 15 : 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.samepace.samepace',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.location_pin,
                        color: AppColors.secondary,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      // A pin without a found name: ask for one instead of
                      // saving raw coordinates.
                      hintText: _picked != null && !_resolvingName
                          ? t('locationPicker.nameThisPlace')
                          : t('locationPicker.search'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching || _resolvingName
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            r.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectResult(r),
                        );
                      },
                    ),
                  )
                else
                  FutureBuilder<List<SavedLocation>>(
                    future: _savedFuture,
                    builder: (context, snapshot) {
                      final saved = snapshot.data ?? [];
                      if (saved.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: saved.map((s) {
                            return InputChip(
                              avatar: const Icon(Icons.star, size: 16),
                              label: Text(
                                placeLabel(s.name),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () =>
                                  _selectResult(s.toPickedLocation()),
                              onDeleted: () => _deleteFavorite(s),
                              deleteIcon: const Icon(Icons.close, size: 16),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              IconButton.outlined(
                onPressed: _picked == null || _saving ? null : _saveFavorite,
                tooltip: t('locationPicker.saveFavorite'),
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _picked == null ? null : _confirm,
                  child: Text(t('locationPicker.confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
