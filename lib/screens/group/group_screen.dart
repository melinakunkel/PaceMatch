import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/profile.dart';
import '../../services/group_service.dart';
import '../../services/message_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

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
                      Icon(group.sport.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('${group.memberCount} Teilnehmer',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _members
                          .map((m) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.secondaryLight,
                                  child: Text(
                                    m.fullName.isNotEmpty
                                        ? m.fullName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.primary, fontSize: 13),
                                  ),
                                ),
                              ))
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
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                          child: const Text('Speichern'),
                        ),
                      ],
                    )
                  else if (group.meetingPoint != null)
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 18, color: AppColors.textSecondary),
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
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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
                return const Center(
                  child: Text('Noch keine Nachrichten. Sag hallo!',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
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
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.secondary : AppColors.surface,
                        border: mine ? null : Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        m.content,
                        style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
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
                  style: IconButton.styleFrom(backgroundColor: AppColors.secondary),
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
