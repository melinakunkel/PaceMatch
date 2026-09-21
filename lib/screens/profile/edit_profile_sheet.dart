import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/interest.dart';
import '../../models/profile.dart';
import '../../models/prompt.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';

const _minAge = 16.0;
const _maxAge = 90.0;

class _PromptEntry {
  _PromptEntry({required this.question, String initialAnswer = ''})
    : controller = TextEditingController(text: initialAnswer);

  final String question;
  final TextEditingController controller;
}

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
  late final _bioCtrl = TextEditingController(text: widget.profile.bio ?? '');
  final List<String> _interests = [];
  final List<String> _languages = [];
  final List<_PromptEntry> _prompts = [];
  bool _saving = false;
  String? _error;

  static const _genders = ['weiblich', 'männlich', 'divers'];

  @override
  void initState() {
    super.initState();
    _interests.addAll(widget.profile.interests);
    _languages.addAll(widget.profile.languages);
    _prompts.addAll(
      widget.profile.prompts.map(
        (p) => _PromptEntry(question: p.question, initialAnswer: p.answer),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    for (final p in _prompts) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _togglePrompt(String question) {
    setState(() {
      final existing = _prompts.indexWhere((p) => p.question == question);
      if (existing != -1) {
        _prompts.removeAt(existing).controller.dispose();
      } else if (_prompts.length < kMaxPrompts) {
        _prompts.add(_PromptEntry(question: question));
      }
    });
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
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          reliabilityScore: widget.profile.reliabilityScore,
          genderPreference: (_sameGenderOnly && _gender != null)
              ? 'same_only'
              : null,
          ageRangeMin: noAgeLimit ? null : _ageRange.start.round(),
          ageRangeMax: noAgeLimit ? null : _ageRange.end.round(),
          isVerified: widget.profile.isVerified,
          interests: _interests,
          languages: _languages,
          autoArchiveInactiveChats: widget.profile.autoArchiveInactiveChats,
          prompts: _prompts
              .where((p) => p.controller.text.trim().isNotEmpty)
              .map(
                (p) => ProfilePrompt(
                  question: p.question,
                  answer: p.controller.text.trim(),
                ),
              )
              .toList(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = t('common.saveFailed', {'error': '$e'}));
      }
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
            Text(
              t('profile.editProfile'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: t('register.name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: t('editProfile.aboutMe'),
                hintText: t('editProfile.aboutMeHint'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('onboarding.step3.age'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cityCtrl,
                    decoration: InputDecoration(
                      labelText: t('onboarding.step3.city'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              t('onboarding.step3.gender'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genders.map((g) {
                return ChoiceChip(
                  label: Text(genderLabel(g)),
                  selected: g == _gender,
                  onSelected: (_) => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              t('onboarding.step4.title'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
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
                  t('editProfile.setGenderFirst'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
            const SizedBox(height: 20),
            Text(
              t('editProfile.languages'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kLanguageOptions.entries.map((entry) {
                final selected = _languages.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _languages.remove(entry.key);
                    } else {
                      _languages.add(entry.key);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              t('editProfile.interestsMax', {'max': '$kMaxInterests'}),
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
                  label: Text(interestLabel(interest)),
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
            const SizedBox(height: 20),
            Text(
              t('editProfile.promptsMax', {'max': '$kMaxPrompts'}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              t('editProfile.promptsHint'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kPromptQuestions.map((q) {
                final selected = _prompts.any((p) => p.question == q);
                final disabled = !selected && _prompts.length >= kMaxPrompts;
                return ChoiceChip(
                  label: Text(promptQuestionLabel(q)),
                  selected: selected,
                  onSelected: disabled ? null : (_) => _togglePrompt(q),
                );
              }).toList(),
            ),
            ..._prompts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: p.controller,
                  maxLength: kMaxPromptAnswerLength,
                  decoration: InputDecoration(
                    labelText: promptQuestionLabel(p.question),
                  ),
                ),
              ),
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
                  : Text(t('newActivity.save')),
            ),
          ],
        ),
      ),
    );
  }
}
