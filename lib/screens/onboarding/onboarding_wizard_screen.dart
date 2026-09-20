import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/sport_type.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pace_format.dart';
import '../../widgets/pace_picker_field.dart';

const _minAge = 16.0;
const _maxAge = 90.0;
const _levels = ['Anfänger', 'Fortgeschritten', 'Profi'];

/// A short guided setup shown once right after registration — picking
/// sports, level/pace and matching preferences up front, instead of
/// dropping a new user onto an empty Home screen with nothing to do.
class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final _profileService = ProfileService();
  late final _ageCtrl = TextEditingController();
  late final _cityCtrl = TextEditingController();

  int _step = 0;
  final Set<SportType> _selectedSports = {};
  final Map<SportType, String> _sportLevels = {};
  final Map<SportType, double?> _paceLow = {};
  final Map<SportType, double?> _paceHigh = {};
  String? _gender;
  bool _sameGenderOnly = false;
  RangeValues _ageRange = const RangeValues(_minAge, _maxAge);
  bool _saving = false;

  static const _stepCount = 4;

  @override
  void dispose() {
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _toggleSport(SportType sport) {
    setState(() {
      if (_selectedSports.contains(sport)) {
        _selectedSports.remove(sport);
      } else {
        _selectedSports.add(sport);
        _sportLevels.putIfAbsent(sport, () => 'Fortgeschritten');
      }
    });
  }

  void _next() {
    if (_step >= _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUserId!;
      for (final sport in _selectedSports) {
        await _profileService.upsertUserSport(
          userId: userId,
          sport: sport,
          level: _sportLevels[sport] ?? 'Fortgeschritten',
          unit: sport.defaultUnit,
          valueLow: sport.usesPace ? _paceLow[sport] : null,
          valueHigh: sport.usesPace ? _paceHigh[sport] : null,
        );
      }
      final noAgeLimit = _ageRange.start <= _minAge && _ageRange.end >= _maxAge;
      final profile = await _profileService.getProfile(userId);
      await _profileService.updateProfile(
        profile.copyWith(
          age: int.tryParse(_ageCtrl.text),
          gender: _gender,
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        ),
      );
      // copyWith can't clear these, so set them directly when needed.
      if ((_sameGenderOnly && _gender != null) || !noAgeLimit) {
        await SupabaseService.ensureFreshSession();
        await SupabaseService.client
            .from('profiles')
            .update({
              'gender_preference': (_sameGenderOnly && _gender != null)
                  ? 'same_only'
                  : null,
              'age_range_min': noAgeLimit ? null : _ageRange.start.round(),
              'age_range_max': noAgeLimit ? null : _ageRange.end.round(),
            })
            .eq('id', userId);
      }
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Los geht\'s'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.go('/'),
            child: const Text('Später'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(_stepCount, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _buildSportsStep(),
                  _buildLevelStep(),
                  _buildBasicsStep(),
                  _buildPreferencesStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : _back,
                      child: const Text('Zurück'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _step == _stepCount - 1 ? 'Fertig' : 'Weiter',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welche Sportarten machst du?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Wähl aus, wonach wir für dich Ausschau halten sollen. Du kannst später jederzeit mehr hinzufügen.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SportType.values.map((sport) {
              final selected = _selectedSports.contains(sport);
              return ChoiceChip(
                label: Text(sport.label),
                selected: selected,
                onSelected: (_) => _toggleSport(sport),
                avatar: Icon(
                  sport.icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wie fit bist du dabei?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Hilft uns, dich mit Leuten auf ähnlichem Niveau zu matchen.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_selectedSports.isEmpty)
            Text(
              'Du hast noch keine Sportart ausgewählt — das holst du im Profil jederzeit nach.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ..._selectedSports.map((sport) {
              final unitLabel = paceUnitLabel(sport.defaultUnit);
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(sport.icon, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          sport.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _levels.map((l) {
                        return ChoiceChip(
                          label: Text(l),
                          selected: _sportLevels[sport] == l,
                          onSelected: (_) =>
                              setState(() => _sportLevels[sport] = l),
                        );
                      }).toList(),
                    ),
                    if (sport.usesPace) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Pace-Bereich ($unitLabel)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PacePickerField(
                              label: 'von',
                              unit: sport.defaultUnit,
                              value: _paceLow[sport],
                              onChanged: (v) =>
                                  setState(() => _paceLow[sport] = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PacePickerField(
                              label: 'bis',
                              unit: sport.defaultUnit,
                              value: _paceHigh[sport],
                              onChanged: (v) =>
                                  setState(() => _paceHigh[sport] = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBasicsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ein paar Basisdaten',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Alles optional — hilft anderen aber, dich besser einzuschätzen.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          const Text('Geschlecht', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['weiblich', 'männlich', 'divers'].map((g) {
              return ChoiceChip(
                label: Text(g),
                selected: g == _gender,
                onSelected: (_) => setState(() => _gender = g),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wer soll dir vorgeschlagen werden?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Kannst du später jederzeit im Profil anpassen.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
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
                'Leg auf der vorigen Seite dein Geschlecht fest, um dies einzuschränken.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        ],
      ),
    );
  }
}
