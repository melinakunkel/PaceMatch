import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../services/activity_service.dart';
import '../../services/chat_request_service.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class _RequestEntry {
  _RequestEntry({required this.profile, required this.activity});
  final Profile profile;
  final Activity activity;
}

/// Inbox for incoming chat requests (activities with discoverVisibility ==
/// 'request') — accepting creates the group chat the same way a direct
/// "Kontaktieren" from Discover already does; declining just removes the
/// request so the sender could try again later.
class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  final _chatRequestService = ChatRequestService();
  final _activityService = ActivityService();
  final _profileService = ProfileService();
  final _groupService = GroupService();

  late Future<List<_RequestEntry>> _future = _load();
  final Set<String> _responding = {};

  Future<List<_RequestEntry>> _load() async {
    final requests = await _chatRequestService.getIncomingRequests();
    if (requests.isEmpty) return [];
    final fromUserIds = requests.map((r) => r['from_user'] as String).toSet();
    final activityIds = requests.map((r) => r['activity_id'] as String).toSet();
    final profiles = await _profileService.getProfilesByIds(
      fromUserIds.toList(),
    );
    final profilesById = {for (final p in profiles) p.id: p};
    final activities = await _activityService.getActivitiesByIds(
      activityIds.toList(),
    );
    final activitiesById = {for (final a in activities) a.id: a};

    final entries = <_RequestEntry>[];
    for (final r in requests) {
      final profile = profilesById[r['from_user']];
      final activity = activitiesById[r['activity_id']];
      if (profile == null || activity == null) continue;
      entries.add(_RequestEntry(profile: profile, activity: activity));
    }
    return entries;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _decline(_RequestEntry entry) async {
    final key = '${entry.profile.id}:${entry.activity.id}';
    setState(() => _responding.add(key));
    try {
      await _chatRequestService.respond(
        fromUser: entry.profile.id,
        activityId: entry.activity.id,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('chatRequests.respondFailed', {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _responding.remove(key));
    }
  }

  Future<void> _accept(_RequestEntry entry) async {
    final key = '${entry.profile.id}:${entry.activity.id}';
    setState(() => _responding.add(key));
    try {
      final groupId = await _groupService.openDirectChat(
        myId: SupabaseService.currentUserId!,
        otherUserId: entry.profile.id,
        sport: entry.activity.sport,
        meetingPoint: entry.activity.locationName,
        latitude: entry.activity.latitude,
        longitude: entry.activity.longitude,
        meetingTime: entry.activity.nextOccurrence,
        activityId: entry.activity.id,
      );
      await _chatRequestService.respond(
        fromUser: entry.profile.id,
        activityId: entry.activity.id,
      );
      if (!mounted) return;
      context.push('/group/$groupId');
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('chatRequests.respondFailed', {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _responding.remove(key));
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
        title: Text(t('chatRequests.title')),
      ),
      body: SafeArea(
        child: FutureBuilder<List<_RequestEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    t('chatRequests.empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                final key = '${entry.profile.id}:${entry.activity.id}';
                final busy = _responding.contains(key);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.secondaryLight,
                          backgroundImage: entry.profile.avatarUrl != null
                              ? NetworkImage(entry.profile.avatarUrl!)
                              : null,
                          child: entry.profile.avatarUrl != null
                              ? null
                              : Text(
                                  entry.profile.firstName.isNotEmpty
                                      ? entry.profile.firstName[0].toUpperCase()
                                      : '?',
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.profile.firstName} ${t('chatRequests.wantsToChat')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.activity.sport.label} · ${entry.activity.timeRangeLabel}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 32,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: () => _accept(entry),
                                  child: Text(t('chatRequests.accept')),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 28,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 28),
                                    foregroundColor: AppColors.textSecondary,
                                  ),
                                  onPressed: () => _decline(entry),
                                  child: Text(t('chatRequests.decline')),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
