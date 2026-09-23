import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/circle.dart';
import '../../models/circle_member.dart';
import '../../services/circle_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Circle details: name/description (editable by admins), invite code with
/// WhatsApp/SMS sharing, and the member list — admins can promote/demote
/// other members, remove them, and delete the circle entirely. The
/// switcher sheet re-fetches its list whenever this screen is popped, so
/// it always ends up in sync (renamed, deleted, or unchanged).
class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({super.key, required this.circle});
  final Circle circle;

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  final _circleService = CircleService();
  late Circle _circle = widget.circle;
  late Future<List<CircleMember>> _future = _load();
  bool _busy = false;

  String get _myId => SupabaseService.currentUserId!;

  Future<List<CircleMember>> _load() => _circleService.getMembers(_circle.id);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _editCircle() async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _EditCircleDialog(circle: _circle),
    );
    if (result == null || result.$1.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _circleService.updateCircle(
        circleId: _circle.id,
        name: result.$1.trim(),
        description: result.$2,
      );
      if (!mounted) return;
      setState(
        () => _circle = Circle(
          id: _circle.id,
          name: result.$1.trim(),
          description: result.$2,
          inviteCode: _circle.inviteCode,
          createdBy: _circle.createdBy,
          createdAt: _circle.createdAt,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('circles.updateFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRole(CircleMember member, bool isAdmin) async {
    setState(() => _busy = true);
    try {
      await _circleService.setMemberRole(
        circleId: _circle.id,
        userId: member.profile.id,
        isAdmin: isAdmin,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(CircleMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('circles.removeMemberTitle')),
        content: Text(
          t('circles.removeMemberConfirm', {'name': member.profile.firstName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t('circles.removeMember'),
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _circleService.removeMember(
        circleId: _circle.id,
        userId: member.profile.id,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _inviteMessage => t('circles.inviteMessage', {
    'circle': _circle.name,
    'code': _circle.inviteCode,
  });

  Future<void> _inviteViaWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_inviteMessage)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('circles.inviteFailed'))));
    }
  }

  Future<void> _inviteViaSms() async {
    final uri = Uri(scheme: 'sms', queryParameters: {'body': _inviteMessage});
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('circles.inviteFailed'))));
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _circle.inviteCode));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('circles.codeCopied'))));
  }

  Future<void> _deleteCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('circles.deleteCircleTitle')),
        content: Text(t('circles.deleteConfirm', {'circle': _circle.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t('circles.deleteCircle'),
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _circleService.deleteCircle(_circle.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('circles.deleteFailed', {'error': '$e'}))),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_circle.name, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: FutureBuilder<List<CircleMember>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t('circles.membersLoadFailed', {
                      'error': '${snapshot.error}',
                    }),
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }
            final members = snapshot.data ?? [];
            final isAdmin = members.any(
              (m) => m.profile.id == _myId && m.isAdmin,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _circle.description?.isNotEmpty == true
                            ? _circle.description!
                            : t('circles.noDescription'),
                        style: TextStyle(
                          color: _circle.description?.isNotEmpty == true
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: t('common.edit'),
                        onPressed: _busy ? null : _editCircle,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('circles.inviteTitle'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _copyCode,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _circle.inviteCode,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t('circles.tapToCopy'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: _inviteViaWhatsApp,
                                icon: const Icon(Icons.chat_outlined),
                                label: Text(t('circles.inviteWhatsApp')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: _inviteViaSms,
                                icon: const Icon(Icons.sms_outlined),
                                label: Text(t('circles.inviteSms')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  t('circles.memberCount', {'count': '${members.length}'}),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...members.map((member) {
                  final isMe = member.profile.id == _myId;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondaryLight,
                        backgroundImage: member.profile.avatarUrl != null
                            ? NetworkImage(member.profile.avatarUrl!)
                            : null,
                        child: member.profile.avatarUrl != null
                            ? null
                            : Text(
                                member.profile.firstName.isNotEmpty
                                    ? member.profile.firstName[0].toUpperCase()
                                    : '?',
                              ),
                      ),
                      title: Text(
                        isMe
                            ? t('circles.meLabel', {
                                'name': member.profile.firstName,
                              })
                            : member.profile.firstName,
                      ),
                      subtitle: member.isAdmin
                          ? Text(
                              t('circles.adminBadge'),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      onTap: () =>
                          context.push('/profile/${member.profile.id}'),
                      trailing: (isAdmin && !isMe)
                          ? PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (action) {
                                if (action == 'toggleAdmin') {
                                  _setRole(member, !member.isAdmin);
                                } else if (action == 'remove') {
                                  _removeMember(member);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggleAdmin',
                                  child: Text(
                                    member.isAdmin
                                        ? t('circles.revokeAdmin')
                                        : t('circles.makeAdmin'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    t('circles.removeMember'),
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
                if (isAdmin) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _deleteCircle,
                      icon: Icon(Icons.delete_outline, color: AppColors.danger),
                      label: Text(
                        t('circles.deleteCircle'),
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditCircleDialog extends StatefulWidget {
  const _EditCircleDialog({required this.circle});
  final Circle circle;

  @override
  State<_EditCircleDialog> createState() => _EditCircleDialogState();
}

class _EditCircleDialogState extends State<_EditCircleDialog> {
  late final _nameCtrl = TextEditingController(text: widget.circle.name);
  late final _descCtrl = TextEditingController(
    text: widget.circle.description ?? '',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop((
    _nameCtrl.text,
    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text,
  ));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('common.edit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(hintText: t('circles.createHint')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: t('circles.descriptionOptional'),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        ElevatedButton(onPressed: _submit, child: Text(t('common.save'))),
      ],
    );
  }
}
