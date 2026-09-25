import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/group.dart';
import '../../services/chat_request_service.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/push_prompt.dart';
import 'chat_requests_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _groupService = GroupService();
  final _profileService = ProfileService();
  final _chatRequestService = ChatRequestService();
  bool _showArchived = false;
  late Future<List<SportGroup>> _future;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadGroups();
    _loadRequestCount();
    UnreadController.messageTick.addListener(_reload);
  }

  @override
  void dispose() {
    UnreadController.messageTick.removeListener(_reload);
    super.dispose();
  }

  Future<void> _loadRequestCount() async {
    final requests = await _chatRequestService.getIncomingRequests();
    if (!mounted) return;
    setState(() => _pendingRequestCount = requests.length);
  }

  Future<void> _openChatRequests() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChatRequestsScreen()));
    _reload();
    _loadRequestCount();
  }

  Future<List<SportGroup>> _loadGroups() async {
    final userId = SupabaseService.currentUserId!;
    if (!_showArchived) {
      final profile = await _profileService.getProfile(userId);
      if (profile.autoArchiveInactiveChats) {
        await _groupService.archiveStaleChats(userId);
      }
    }
    return _groupService.getMyGroups(userId, archived: _showArchived);
  }

  void _reload() {
    setState(() {
      _future = _loadGroups();
    });
  }

  Future<void> _archive(SportGroup g, bool archived) async {
    await _groupService.setArchived(
      groupId: g.id,
      userId: SupabaseService.currentUserId!,
      archived: archived,
    );
    _reload();
  }

  /// Leaving a private chat deletes it for both people (database trigger),
  /// so it's worded as deleting — for either side.
  Future<void> _leave(SportGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          g.isDirect ? t('chatList.deleteTitle') : t('chatList.leaveTitle'),
        ),
        content: Text(
          g.isDirect
              ? t('chatList.deleteDirectConfirm', {'name': g.displayName})
              : t('chatList.leaveConfirm', {'name': g.displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(g.isDirect ? t('common.delete') : t('chatList.leave')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _groupService.leaveGroup(
      groupId: g.id,
      userId: SupabaseService.currentUserId!,
    );
    _reload();
    UnreadController.refresh();
  }

  Future<void> _delete(SportGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('chatList.deleteTitle')),
        content: Text(t('chatList.deleteConfirm', {'name': g.displayName})),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _groupService.deleteGroup(g.id);
    _reload();
    UnreadController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    return AppScaffold(
      currentIndex: 3,
      title: _showArchived ? t('chatList.archivedTitle') : t('chatList.title'),
      actions: [
        IconButton(
          tooltip: t('chatList.chatRequests'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.mail_outline),
              if (_pendingRequestCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _openChatRequests,
        ),
        IconButton(
          tooltip: _showArchived
              ? t('chatList.showActive')
              : t('chatList.showArchived'),
          icon: Icon(
            _showArchived ? Icons.chat_bubble_outline : Icons.archive_outlined,
          ),
          onPressed: () {
            setState(() => _showArchived = !_showArchived);
            _reload();
          },
        ),
      ],
      body: FutureBuilder<List<SportGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _showArchived
                      ? t('chatList.emptyArchived')
                      : t('chatList.emptyActive'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          // Private chats (one per person) first, newest activity on top;
          // group chats (events, deliberate group chats) below.
          final direct = groups.where((g) => g.isDirect).toList()
            ..sort(
              (a, b) => (b.lastActivityAt ?? DateTime(2000)).compareTo(
                a.lastActivityAt ?? DateTime(2000),
              ),
            );
          final grouped = groups.where((g) => !g.isDirect).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_showArchived) const PushPromptCard(),
              if (direct.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.person_outline,
                  label: t('chatList.directSection'),
                ),
                ...direct.map((g) => _buildTile(g, myId)),
              ],
              if (grouped.isNotEmpty) ...[
                if (direct.isNotEmpty) const SizedBox(height: 8),
                _SectionHeader(
                  icon: Icons.groups_outlined,
                  label: t('chatList.groupSection'),
                ),
                ...grouped.map((g) => _buildTile(g, myId)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTile(SportGroup g, String? myId) {
    final isCreator = g.createdBy == myId;
    final partner = g.partner;
    final avatarUrl = partner?.avatarUrl;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            if (g.isDirect)
              CircleAvatar(
                backgroundColor: AppColors.secondaryLight,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl != null
                    ? null
                    : Text(
                        g.displayName.isNotEmpty
                            ? g.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: AppColors.primary),
                      ),
              )
            else
              CircleAvatar(
                backgroundColor: AppColors.secondaryLight,
                child: Icon(g.sport.icon, color: AppColors.primary),
              ),
            if (g.hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          g.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: g.hasUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          _subtitle(g),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'archive':
                _archive(g, true);
                break;
              case 'unarchive':
                _archive(g, false);
                break;
              case 'leave':
                _leave(g);
                break;
              case 'delete':
                _delete(g);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!_showArchived)
              PopupMenuItem(
                value: 'archive',
                child: Text(t('chatList.archive')),
              )
            else
              PopupMenuItem(
                value: 'unarchive',
                child: Text(t('chatList.unarchive')),
              ),
            if (g.isDirect)
              PopupMenuItem(value: 'leave', child: Text(t('common.delete')))
            else if (isCreator)
              PopupMenuItem(value: 'delete', child: Text(t('common.delete')))
            else
              PopupMenuItem(value: 'leave', child: Text(t('chatList.leave'))),
          ],
        ),
        onTap: () => context.push('/group/${g.id}').then((_) => _reload()),
      ),
    );
  }

  /// Private chat: which sport and when/where they meet next. Group chat:
  /// when/where, plus how many are in it.
  static String _subtitle(SportGroup g) {
    final upcoming =
        g.meetingTime != null &&
        g.meetingTime!.isAfter(
          DateTime.now().subtract(const Duration(hours: 12)),
        );
    return [
      if (g.isDirect) g.sport.label,
      if (g.meetingTime != null && (upcoming || !g.isDirect))
        formatMeetupTime(g.meetingTime!),
      if (g.meetingPoint != null && (upcoming || !g.isDirect))
        placeLabel(g.meetingPoint!),
      if (!g.isDirect)
        t('chatList.participants', {'count': '${g.memberCount}'}),
    ].join(' · ');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
