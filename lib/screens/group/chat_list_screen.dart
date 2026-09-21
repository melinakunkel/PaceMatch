import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

String _formatMeetingTime(DateTime t) {
  final day = weekdayLabels[t.weekday - 1];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$day, ${t.day}.${t.month}. $hh:$mm';
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _groupService = GroupService();
  final _profileService = ProfileService();
  bool _showArchived = false;
  late Future<List<SportGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadGroups();
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

  Future<void> _leave(SportGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('chatList.leaveTitle')),
        content: Text(t('chatList.leaveConfirm', {'name': g.name})),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(t('chatList.leave')),
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
        content: Text(t('chatList.deleteConfirm', {'name': g.name})),
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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              final isCreator = g.createdBy == myId;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
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
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: g.hasUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (g.meetingTime != null)
                        _formatMeetingTime(g.meetingTime!),
                      if (g.meetingPoint != null) g.meetingPoint!,
                      t('chatList.participants', {'count': '${g.memberCount}'}),
                    ].join(' · '),
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
                      if (isCreator)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(t('common.delete')),
                        )
                      else
                        PopupMenuItem(
                          value: 'leave',
                          child: Text(t('chatList.leave')),
                        ),
                    ],
                  ),
                  onTap: () =>
                      context.push('/group/${g.id}').then((_) => _reload()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
