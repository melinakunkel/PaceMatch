import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/profile.dart';
import '../../services/block_service.dart';
import '../../services/report_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';

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
  bool _alsoBlock = true;
  bool _sending = false;
  bool _sent = false;
  bool _blocked = false;
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
        details: _detailsCtrl.text.trim().isEmpty
            ? null
            : _detailsCtrl.text.trim(),
      );
      if (_alsoBlock) {
        await BlockService().blockUser(_selectedMember!.id);
      }
      if (mounted) {
        setState(() {
          _sent = true;
          _blocked = _alsoBlock;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = t('report.submitFailed', {'error': '$e'}));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('group.reportUser')),
      content: _sent
          ? Text(t('report.thanks'))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.members.isEmpty)
                  Text(t('report.noOtherMembers'))
                else ...[
                  Text(t('report.whoToReport')),
                  const SizedBox(height: 8),
                  DropdownButton<Profile>(
                    isExpanded: true,
                    value: _selectedMember,
                    items: widget.members
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMember = v),
                  ),
                  const SizedBox(height: 16),
                  Text(t('report.reason')),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _reason,
                    items: _reasons
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(reportReasonLabel(r)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _reason = v ?? _reasons.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _detailsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: t('report.detailsOptional'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _alsoBlock,
                    onChanged: (v) => setState(() => _alsoBlock = v ?? true),
                    title: Text(t('report.alsoBlock')),
                    subtitle: Text(t('report.alsoBlockSubtitle')),
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
          onPressed: () => Navigator.of(context).pop(_blocked),
          child: Text(_sent ? t('common.close') : t('common.cancel')),
        ),
        if (!_sent && widget.members.isNotEmpty)
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(t('report.submit')),
          ),
      ],
    );
  }
}
