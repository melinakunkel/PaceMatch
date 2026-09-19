import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _profileService = ProfileService();
  late final _nameCtrl = TextEditingController(text: widget.profile.fullName);
  late final _ageCtrl = TextEditingController(text: widget.profile.age?.toString() ?? '');
  late final _cityCtrl = TextEditingController(text: widget.profile.city ?? '');
  late String? _gender = widget.profile.gender;
  bool _saving = false;

  static const _genders = ['weiblich', 'männlich', 'divers'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.updateProfile(Profile(
        id: widget.profile.id,
        fullName: _nameCtrl.text.trim().isEmpty ? widget.profile.fullName : _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text),
        gender: _gender,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        avatarUrl: widget.profile.avatarUrl,
        bio: widget.profile.bio,
      ));
      if (mounted) Navigator.of(context).pop();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profil bearbeiten',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
          const Text('Geschlecht', style: TextStyle(fontWeight: FontWeight.w600)),
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
