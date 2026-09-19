import 'package:flutter/material.dart';

import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/profile_service.dart';

class EditSportSheet extends StatefulWidget {
  const EditSportSheet({super.key, required this.userId, this.existing});

  final String userId;
  final UserSport? existing;

  @override
  State<EditSportSheet> createState() => _EditSportSheetState();
}

class _EditSportSheetState extends State<EditSportSheet> {
  final _profileService = ProfileService();
  late SportType _sport = widget.existing?.sport ?? SportType.laufen;
  late String _level = widget.existing?.level ?? 'Fortgeschritten';
  final _lowCtrl = TextEditingController();
  final _highCtrl = TextEditingController();
  bool _saving = false;

  static const _levels = ['Anfänger', 'Fortgeschritten', 'Profi'];

  @override
  void initState() {
    super.initState();
    _lowCtrl.text = widget.existing?.valueLow?.toString() ?? '';
    _highCtrl.text = widget.existing?.valueHigh?.toString() ?? '';
  }

  @override
  void dispose() {
    _lowCtrl.dispose();
    _highCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.upsertUserSport(
        userId: widget.userId,
        sport: _sport,
        level: _level,
        unit: _sport.defaultUnit,
        valueLow: double.tryParse(_lowCtrl.text.replaceAll(',', '.')),
        valueHigh: double.tryParse(_highCtrl.text.replaceAll(',', '.')),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _sport.defaultUnit == 'km_per_h' ? 'km/h' : 'min/km';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sportart & Level',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SportType.values.map((s) {
              return ChoiceChip(
                label: Text(s.label),
                selected: s == _sport,
                onSelected: (_) => setState(() => _sport = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _levels.map((l) {
              return ChoiceChip(
                label: Text(l),
                selected: l == _level,
                onSelected: (_) => setState(() => _level = l),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Pace-Bereich ($unitLabel)',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lowCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'von'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _highCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'bis'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
