import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/picked_location.dart';
import '../../models/sport_type.dart';
import '../../services/activity_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pace_picker_field.dart';
import 'location_picker_screen.dart';

class NewActivityScreen extends StatefulWidget {
  const NewActivityScreen({super.key, required this.initialSport});

  final SportType initialSport;

  @override
  State<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends State<NewActivityScreen> {
  final _activityService = ActivityService();
  final _radiusCtrl = TextEditingController(text: '3');
  final _distanceMinCtrl = TextEditingController();
  final _distanceMaxCtrl = TextEditingController();

  late SportType _sport = widget.initialSport;
  final Set<int> _selectedDays = {DateTime.now().weekday};
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 0);
  PickedLocation? _location;
  double? _paceMin;
  double? _paceMax;
  bool _saving = false;

  @override
  void dispose() {
    _radiusCtrl.dispose();
    _distanceMinCtrl.dispose();
    _distanceMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) return;
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUserId!;
      final days = _selectedDays.toList()..sort();
      final created = <Activity>[];
      for (final day in days) {
        created.add(await _activityService.createActivity(
          userId: userId,
          sport: _sport,
          dayOfWeek: day,
          startTime: _start,
          endTime: _end,
          locationName: _location?.name,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          radiusKm: double.tryParse(_radiusCtrl.text.replaceAll(',', '.')) ?? 3,
          distanceMinKm: double.tryParse(_distanceMinCtrl.text.replaceAll(',', '.')),
          distanceMaxKm: double.tryParse(_distanceMaxCtrl.text.replaceAll(',', '.')),
          paceMin: _paceMin,
          paceMax: _paceMax,
        ));
      }
      if (!mounted) return;
      if (created.length == 1) {
        context.pushReplacement('/matches/${created.first.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${created.length} Sportzeiten hinzugefügt.')),
        );
        context.pushReplacement('/plan');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paceUnitLabel =
        _sport.defaultUnit == 'km_per_h' ? 'km/h' : 'min/km';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Neue Aktivität'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _SectionLabel('Sportart'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SportType.values.map((sport) {
                final selected = sport == _sport;
                return ChoiceChip(
                  label: Text(sport.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _sport = sport),
                  avatar: Icon(sport.icon,
                      size: 18,
                      color: selected ? AppColors.primary : AppColors.textSecondary),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Wann? (mehrere Tage möglich)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(weekdayLabels[i]),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedDays.add(day);
                    } else if (_selectedDays.length > 1) {
                      _selectedDays.remove(day);
                    }
                  }),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Von',
                    time: _start,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'Bis',
                    time: _end,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Wo?'),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'Ort auf der Karte auswählen',
                  prefixIcon: Icon(Icons.place_outlined),
                  suffixIcon: Icon(Icons.map_outlined),
                ),
                child: Text(
                  _location?.name ?? 'Ort auf der Karte auswählen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _location == null
                      ? const TextStyle(color: AppColors.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Umkreis (km)',
                prefixIcon: Icon(Icons.social_distance_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Distanz (km)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _distanceMinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'von'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _distanceMaxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'bis'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Pace ($paceUnitLabel)'),
            Row(
              children: [
                Expanded(
                  child: PacePickerField(
                    label: 'von',
                    unit: _sport.defaultUnit,
                    value: _paceMin,
                    onChanged: (v) => setState(() => _paceMin = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PacePickerField(
                    label: 'bis',
                    unit: _sport.defaultUnit,
                    value: _paceMax,
                    onChanged: (v) => setState(() => _paceMax = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_selectedDays.length > 1
                      ? 'Veröffentlichen (${_selectedDays.length} Tage)'
                      : 'Veröffentlichen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.schedule)),
        child: Text(Activity.formatTime(time)),
      ),
    );
  }
}
