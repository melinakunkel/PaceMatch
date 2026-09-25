import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/sport_type.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';
import '../../utils/pace_format.dart';
import '../../widgets/pace_picker_field.dart';
import '../../widgets/city_picker_field.dart';

const _minAge = 16.0;
const _maxAge = 90.0;
const _levels = ['Anfänger', 'Fortgeschritten', 'Profi'];

/// A short guided setup shown once right after registration — picking
/// sports, level/pace and matching preferences up front, instead of
/// dropping a new user onto an empty Home screen with nothing to do.
class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final _profileService = ProfileService();
  late final _ageCtrl = TextEditingController();
  String? _city;

  /// City text typed but not yet picked from the list.
  bool _cityPending = false;

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
    if (_step == 2 && _cityPending) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('city.pickFromList'))));
      return;
    }
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
          level: sport.usesLevel
              ? (_sportLevels[sport] ?? 'Fortgeschritten')
              : null,
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
          city: _city,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t('onboarding.title')),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.go('/'),
            child: Text(t('onboarding.later')),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
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
          ],
        ),
      ),
      // A Scaffold-managed bottom bar (rather than the last item in the
      // body's Column) so it's always pinned above the safe area
      // regardless of how tall the step content ends up being.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _saving ? null : _back,
                  child: Text(t('onboarding.back')),
                ),
              const Spacer(),
              ElevatedButton(
                // Theme's default minimumSize is full-width
                // (Size.fromHeight) — inside a Row that gets unbounded
                // incoming width and silently breaks layout, so this needs
                // its own compact minimumSize.
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
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
                        _step == _stepCount - 1
                            ? t('tutorial.done')
                            : t('common.next'),
                      ),
              ),
            ],
          ),
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
          Text(
            t('onboarding.step1.title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('onboarding.step1.subtitle'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SportType.alphabetical.map((sport) {
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
          Text(
            t('onboarding.step2.title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('onboarding.step2.subtitle'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_selectedSports.isEmpty)
            Text(
              t('onboarding.step2.noSports'),
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            // One card per sport, so it's clear which level/pace belongs to
            // which — and that e.g. Wandern simply has no pace.
            ..._selectedSports.map((sport) {
              final unitLabel = paceUnitLabel(sport.defaultUnit);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.secondaryLight,
                            child: Icon(
                              sport.icon,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            sport.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (sport.usesLevel) ...[
                        const SizedBox(height: 12),
                        Text(
                          t('onboarding.step2.level'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _levels.map((l) {
                            return ChoiceChip(
                              label: Text(levelLabel(l)),
                              selected: _sportLevels[sport] == l,
                              onSelected: (_) =>
                                  setState(() => _sportLevels[sport] = l),
                            );
                          }).toList(),
                        ),
                      ],
                      if (sport.usesPace) ...[
                        const SizedBox(height: 12),
                        Text(
                          t('onboarding.step2.paceRange', {
                            'sport': sport.label,
                            'unit': unitLabel,
                          }),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: PacePickerField(
                                label: t('common.from'),
                                unit: sport.defaultUnit,
                                value: _paceLow[sport],
                                onChanged: (v) =>
                                    setState(() => _paceLow[sport] = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PacePickerField(
                                label: t('common.to'),
                                unit: sport.defaultUnit,
                                value: _paceHigh[sport],
                                onChanged: (v) =>
                                    setState(() => _paceHigh[sport] = v),
                              ),
                            ),
                          ],
                        ),
                      ] else if (sport.usesLevel) ...[
                        const SizedBox(height: 10),
                        Text(
                          t('onboarding.step2.noPace', {'sport': sport.label}),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
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
          Text(
            t('onboarding.step3.title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('onboarding.step3.subtitle'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t('onboarding.step3.age')),
          ),
          const SizedBox(height: 12),
          CityPickerField(
            initialCity: _city,
            onChanged: (city, pending) {
              _city = city;
              _cityPending = pending;
            },
          ),
          const SizedBox(height: 20),
          Text(
            t('onboarding.step3.gender'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['weiblich', 'männlich', 'divers'].map((g) {
              return ChoiceChip(
                label: Text(genderLabel(g)),
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
          Text(
            t('onboarding.step4.title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('onboarding.step4.subtitle'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(t('onboarding.step4.anyone')),
                selected: !_sameGenderOnly,
                onSelected: (_) => setState(() => _sameGenderOnly = false),
              ),
              ChoiceChip(
                label: Text(t('onboarding.step4.sameGenderOnly')),
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
                t('onboarding.step4.setGenderFirst'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            t('onboarding.step4.ageRange', {
              'min': _ageRange.start.round().toString(),
              'max': _ageRange.end.round().toString(),
              'unlimited':
                  _ageRange.start <= _minAge && _ageRange.end >= _maxAge
                  ? t('onboarding.step4.unlimited')
                  : '',
            }),
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
