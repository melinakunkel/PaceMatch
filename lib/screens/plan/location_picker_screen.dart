import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/picked_location.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';

/// Full-screen OpenStreetMap picker: search a place, tap the map to fine-tune
/// the pin, confirm to return a [PickedLocation].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _viennaFallback = LatLng(48.2082, 16.3738);

  final _geocoding = GeocodingService();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();

  Timer? _debounce;
  List<PickedLocation> _results = [];
  bool _searching = false;

  LatLng? _picked;
  String? _pickedName;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _picked = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _pickedName = widget.initial!.name;
      _searchCtrl.text = widget.initial!.name;
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
    });
    final name = await _geocoding.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted || _picked != point) return;
    setState(() {
      _pickedName =
          name ??
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      _searchCtrl.text = _pickedName!;
    });
  }

  void _confirm() {
    if (_picked == null) return;
    Navigator.of(context).pop(
      PickedLocation(
        name:
            _pickedName ??
            '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
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
        title: const Text('Ort auswählen'),
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
                      hintText: 'Ort suchen, z.B. Prater',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
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
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _picked == null ? null : _confirm,
            child: const Text('Diesen Ort übernehmen'),
          ),
        ),
      ),
    );
  }
}
