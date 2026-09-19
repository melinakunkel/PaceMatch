import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/supabase_service.dart';
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
  late Future<List<SportGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = GroupService().getMyGroups(SupabaseService.currentUserId!);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 3,
      title: 'Gruppen & Chats',
      body: FutureBuilder<List<SportGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Noch keine Gruppen. Erstelle eine Gruppe über deine Matches.',
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    child: Icon(g.sport.icon, color: AppColors.primary),
                  ),
                  title: Text(g.name),
                  subtitle: Text(
                    [
                      if (g.meetingTime != null) _formatMeetingTime(g.meetingTime!),
                      if (g.meetingPoint != null) g.meetingPoint!,
                      '${g.memberCount} Teilnehmer',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/group/${g.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
