import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/profile_service.dart';
import '../../utils/display_labels.dart';
import '../../utils/pace_format.dart';
import '../../widgets/pace_picker_field.dart';

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
  late double? _valueLow = widget.existing?.valueLow;
  late double? _valueHigh = widget.existing?.valueHigh;
  bool _saving = false;

  static const _levels = ['Anfänger', 'Fortgeschritten', 'Profi'];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.upsertUserSport(
        userId: widget.userId,
        sport: _sport,
        level: _sport.usesLevel ? _level : null,
        unit: _sport.defaultUnit,
        valueLow: _sport.usesPace ? _valueLow : null,
        valueHigh: _sport.usesPace ? _valueHigh : null,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = paceUnitLabel(_sport.defaultUnit);
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
          Text(
            t('editSport.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SportType.selectable.map((s) {
              return ChoiceChip(
                label: Text(s.label),
                selected: s == _sport,
                onSelected: (_) => setState(() => _sport = s),
              );
            }).toList(),
          ),
          if (_sport.usesLevel) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _levels.map((l) {
                return ChoiceChip(
                  label: Text(levelLabel(l)),
                  selected: l == _level,
                  onSelected: (_) => setState(() => _level = l),
                );
              }).toList(),
            ),
          ],
          if (_sport.usesPace) ...[
            const SizedBox(height: 16),
            Text(
              t('onboarding.step2.paceRange', {'unit': unitLabel}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PacePickerField(
                    label: t('common.from'),
                    unit: _sport.defaultUnit,
                    value: _valueLow,
                    onChanged: (v) => setState(() => _valueLow = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PacePickerField(
                    label: t('common.to'),
                    unit: _sport.defaultUnit,
                    value: _valueHigh,
                    onChanged: (v) => setState(() => _valueHigh = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(t('newActivity.save')),
          ),
        ],
      ),
    );
  }
}
