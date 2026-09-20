import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/report_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class ReportUserDialog extends StatefulWidget {
  const ReportUserDialog({super.key, required this.members, this.groupId});

  /// Group members excluding the current user.
  final List<Profile> members;
  final String? groupId;

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  static const _reasons = [
    'Belästigung',
    'Unangemessenes Verhalten',
    'Nicht erschienen',
    'Fake-Profil',
    'Sonstiges',
  ];

  Profile? _selectedMember;
  String _reason = _reasons.first;
  final _detailsCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.members.isNotEmpty ? widget.members.first : null;
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedMember == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ReportService().submitReport(
        reporterId: SupabaseService.currentUserId!,
        reportedUserId: _selectedMember!.id,
        groupId: widget.groupId,
        reason: _reason,
        details: _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Melden fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Person melden'),
      content: _sent
          ? const Text(
              'Danke, deine Meldung wurde übermittelt. Wir schauen uns das an.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.members.isEmpty)
                  const Text('Keine anderen Mitglieder in dieser Gruppe.')
                else ...[
                  const Text('Wen möchtest du melden?'),
                  const SizedBox(height: 8),
                  DropdownButton<Profile>(
                    isExpanded: true,
                    value: _selectedMember,
                    items: widget.members
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.fullName)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMember = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Grund'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _reason,
                    items: _reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _reason = v ?? _reasons.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _detailsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: AppColors.danger)),
                  ],
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_sent ? 'Schließen' : 'Abbrechen'),
        ),
        if (!_sent && widget.members.isNotEmpty)
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Melden'),
          ),
      ],
    );
  }
}
