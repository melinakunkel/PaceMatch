import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart' show weekdayLabels;
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/profile.dart';
import '../../services/group_service.dart';
import '../../services/message_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import 'report_user_dialog.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupService = GroupService();
  final _meetingPointCtrl = TextEditingController();

  SportGroup? _group;
  List<Profile> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await _groupService.getGroup(widget.groupId);
    final members = await _groupService.getGroupMembers(widget.groupId);
    final myId = SupabaseService.currentUserId;
    if (myId != null) {
      await _groupService.markGroupRead(groupId: widget.groupId, userId: myId);
      UnreadController.refresh();
    }
    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _meetingPointCtrl.text = group.meetingPoint ?? '';
      _loading = false;
    });
  }

  Future<void> _setMeetingPoint() async {
    if (_meetingPointCtrl.text.trim().isEmpty) return;
    await _groupService.updateMeetingPoint(
      groupId: widget.groupId,
      meetingPoint: _meetingPointCtrl.text.trim(),
    );
    _load();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _meetingPointCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final group = _group!;
    final myId = SupabaseService.currentUserId;
    final isCreator = group.createdBy == myId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Person melden',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ReportUserDialog(
                members: _members.where((m) => m.id != myId).toList(),
                groupId: widget.groupId,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        group.sport.icon,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${group.memberCount} Teilnehmer',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _members
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => context.push(
                                  m.id == myId
                                      ? '/profile'
                                      : '/profile/${m.id}',
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.secondaryLight,
                                  backgroundImage: m.avatarUrl != null
                                      ? NetworkImage(m.avatarUrl!)
                                      : null,
                                  child: m.avatarUrl != null
                                      ? null
                                      : Text(
                                          m.fullName.isNotEmpty
                                              ? m.fullName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isCreator)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _meetingPointCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Treffpunkt festlegen',
                              prefixIcon: Icon(Icons.place_outlined),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _setMeetingPoint,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Speichern'),
                        ),
                      ],
                    )
                  else if (group.meetingPoint != null)
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(group.meetingPoint!),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _ChatView(groupId: widget.groupId)),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.groupId});
  final String groupId;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageService = MessageService();
  final _groupService = GroupService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastSeenMessageId;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await _messageService.sendMessage(
      groupId: widget.groupId,
      senderId: SupabaseService.currentUserId!,
      content: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messageService.streamMessages(widget.groupId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Noch keine Nachrichten. Sag hallo!',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              final lastMessage = messages.last;
              if (lastMessage.id != _lastSeenMessageId) {
                _lastSeenMessageId = lastMessage.id;
                if (myId != null) {
                  _groupService
                      .markGroupRead(groupId: widget.groupId, userId: myId)
                      .then((_) => UnreadController.refresh());
                }
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final mine = m.senderId == myId;
                  final showDateDivider =
                      index == 0 ||
                      !_isSameDay(messages[index - 1].createdAt, m.createdAt);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateDivider) _DateDivider(date: m.createdAt),
                      Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.secondary
                                    : AppColors.surface,
                                border: mine
                                    ? null
                                    : Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                m.content,
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _formatMessageTime(m.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nachricht schreiben...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String _formatMessageTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatDateDividerLabel(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  if (_isSameDay(local, now)) return 'Heute';
  if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
    return 'Gestern';
  }
  return '${weekdayLabels[local.weekday - 1]}, '
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatDateDividerLabel(date),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}
