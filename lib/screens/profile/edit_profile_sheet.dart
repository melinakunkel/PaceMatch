import 'package:flutter/material.dart';

import '../../models/interest.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

const _minAge = 16.0;
const _maxAge = 90.0;

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _profileService = ProfileService();
  late final _nameCtrl = TextEditingController(text: widget.profile.fullName);
  late final _ageCtrl = TextEditingController(
    text: widget.profile.age?.toString() ?? '',
  );
  late final _cityCtrl = TextEditingController(text: widget.profile.city ?? '');
  late String? _gender = widget.profile.gender;
  late bool _sameGenderOnly = widget.profile.genderPreference == 'same_only';
  late RangeValues _ageRange = RangeValues(
    (widget.profile.ageRangeMin ?? _minAge.toInt()).toDouble().clamp(
      _minAge,
      _maxAge,
    ),
    (widget.profile.ageRangeMax ?? _maxAge.toInt()).toDouble().clamp(
      _minAge,
      _maxAge,
    ),
  );
  final List<String> _interests = [];
  late String? _language = widget.profile.language;
  bool _saving = false;
  String? _error;

  static const _genders = ['weiblich', 'männlich', 'divers'];

  @override
  void initState() {
    super.initState();
    _interests.addAll(widget.profile.interests);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final noAgeLimit = _ageRange.start <= _minAge && _ageRange.end >= _maxAge;
      await _profileService.updateProfile(
        Profile(
          id: widget.profile.id,
          fullName: _nameCtrl.text.trim().isEmpty
              ? widget.profile.fullName
              : _nameCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text),
          gender: _gender,
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          avatarUrl: widget.profile.avatarUrl,
          bio: widget.profile.bio,
          reliabilityScore: widget.profile.reliabilityScore,
          genderPreference: (_sameGenderOnly && _gender != null)
              ? 'same_only'
              : null,
          ageRangeMin: noAgeLimit ? null : _ageRange.start.round(),
          ageRangeMax: noAgeLimit ? null : _ageRange.end.round(),
          isVerified: widget.profile.isVerified,
          interests: _interests,
          language: _language,
          autoArchiveInactiveChats: widget.profile.autoArchiveInactiveChats,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Speichern fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil bearbeiten',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Alter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'Stadt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Geschlecht',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genders.map((g) {
                return ChoiceChip(
                  label: Text(g),
                  selected: g == _gender,
                  onSelected: (_) => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Wer soll dir vorgeschlagen werden?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Egal'),
                  selected: !_sameGenderOnly,
                  onSelected: (_) => setState(() => _sameGenderOnly = false),
                ),
                ChoiceChip(
                  label: const Text('Nur mein Geschlecht'),
                  selected: _sameGenderOnly,
                  onSelected: _gender == null
                      ? null
                      : (_) => setState(() => _sameGenderOnly = true),
                ),
              ],
            ),
            if (_gender == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Lege oben dein Geschlecht fest, um dies einzuschränken.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Altersbereich: ${_ageRange.start.round()} - ${_ageRange.end.round()} Jahre'
              '${_ageRange.start <= _minAge && _ageRange.end >= _maxAge ? ' (unbegrenzt)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            RangeSlider(
              values: _ageRange,
              min: _minAge,
              max: _maxAge,
              divisions: (_maxAge - _minAge).round(),
              labels: RangeLabels(
                _ageRange.start.round().toString(),
                _ageRange.end.round().toString(),
              ),
              onChanged: (v) => setState(() => _ageRange = v),
            ),
            const SizedBox(height: 20),
            Text(
              'Sprache',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kLanguageOptions.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == _language,
                  onSelected: (_) => setState(() => _language = entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Interessen (max. $kMaxInterests)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kInterestOptions.map((interest) {
                final selected = _interests.contains(interest);
                final disabled =
                    !selected && _interests.length >= kMaxInterests;
                return ChoiceChip(
                  label: Text(interest),
                  selected: selected,
                  onSelected: disabled
                      ? null
                      : (_) => setState(() {
                          if (selected) {
                            _interests.remove(interest);
                          } else {
                            _interests.add(interest);
                          }
                        }),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
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
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
