import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/buddy.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../services/activity_service.dart';
import '../../services/group_service.dart';
import '../../services/like_service.dart';
import '../../services/match_notifier.dart';
import '../../services/match_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/verified_badge.dart';

class _MatchedActivity {
  _MatchedActivity({required this.activity, required this.matchCount});
  final Activity activity;
  final int matchCount;
}

/// Sportbuddys tab: an overview of people you've mutually connected with
/// (see below), plus your own activities that currently have candidates
/// worth swiping through.
class MatchesHubScreen extends StatefulWidget {
  const MatchesHubScreen({super.key});

  @override
  State<MatchesHubScreen> createState() => _MatchesHubScreenState();
}

class _MatchesHubScreenState extends State<MatchesHubScreen> {
  final _activityService = ActivityService();
  final _matchService = MatchService();
  final _likeService = LikeService();
  final _profileService = ProfileService();
  final _groupService = GroupService();

  late Future<List<_MatchedActivity>> _future;
  List<Profile> _buddies = [];
  final Map<String, String?> _chatByBuddy = {};
  bool _buddiesLoading = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadBuddies();
    MatchNotifier.markSeen();
  }

  Future<List<_MatchedActivity>> _load() async {
    final activities = await _activityService.getMyActivities(
      SupabaseService.currentUserId!,
    );
    final results = <_MatchedActivity>[];
    for (final a in activities) {
      final matches = await _matchService.findMatches(a);
      if (matches.isNotEmpty) {
        results.add(_MatchedActivity(activity: a, matchCount: matches.length));
      }
    }
    results.sort((a, b) => b.matchCount.compareTo(a.matchCount));
    return results;
  }

  Future<void> _loadBuddies() async {
    setState(() => _buddiesLoading = true);
    try {
      final userId = SupabaseService.currentUserId!;
      final buddies = await _likeService.getBuddies(userId);
      final profiles = await _profileService.getProfilesByIds(
        buddies.map((b) => b.userId).toList(),
      );
      final profilesById = {for (final p in profiles) p.id: p};
      final ordered = buddies
          .map((b) => profilesById[b.userId])
          .whereType<Profile>()
          .toList();
      final chatMap = <String, String?>{};
      for (final p in ordered) {
        chatMap[p.id] = await _groupService.findSharedGroupId(p.id);
      }
      if (!mounted) return;
      setState(() {
        _buddies = ordered;
        _chatByBuddy
          ..clear()
          ..addAll(chatMap);
        _buddiesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _buddiesLoading = false);
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await Future.wait([future, _loadBuddies()]);
  }

  Future<void> _startChat(Profile buddy) async {
    final existing = _chatByBuddy[buddy.id];
    if (existing != null) {
      context.push('/group/$existing');
      return;
    }
    final me = SupabaseService.currentUserId!;
    try {
      final buddies = await _likeService.getBuddies(me);
      final activityId = buddies
          .firstWhere(
            (b) => b.userId == buddy.id,
            orElse: () => Buddy(userId: buddy.id, connectedAt: DateTime.now()),
          )
          .activityId;
      final activity = await _groupService.getActivity(activityId);
      final group = await _groupService.createGroup(
        createdBy: me,
        sport: activity?.sport ?? SportType.sonstige,
        name: 'Sportbuddy: ${buddy.fullName}',
        meetingPoint: activity?.locationName,
        latitude: activity?.latitude,
        longitude: activity?.longitude,
        meetingTime: activity?.nextOccurrence,
        activityId: activity?.id,
        isMatch: true,
      );
      await _groupService.joinGroup(groupId: group.id, userId: buddy.id);
      if (!mounted) return;
      setState(() => _chatByBuddy[buddy.id] = group.id);
      context.push('/group/${group.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chat konnte nicht erstellt werden: $e')));
    }
  }

  Future<void> _openBuddySheet(Profile buddy) async {
    final hasChat = _chatByBuddy[buddy.id] != null;
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondaryLight,
                    backgroundImage: buddy.avatarUrl != null
                        ? NetworkImage(buddy.avatarUrl!)
                        : null,
                    child: buddy.avatarUrl != null
                        ? null
                        : Text(
                            buddy.fullName.isNotEmpty
                                ? buddy.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            buddy.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (buddy.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/profile/${buddy.id}');
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Profil ansehen'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startChat(buddy);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(hasChat ? 'Chat öffnen' : 'Chat starten'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2,
      title: 'Sportbuddys',
      body: FutureBuilder<List<_MatchedActivity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _buddiesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final matched = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_buddies.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Deine Sportbuddys',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  SizedBox(
                    height: 92,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _buddies.length,
                      itemBuilder: (context, index) {
                        final b = _buddies[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () => _openBuddySheet(b),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.secondaryLight,
                                  backgroundImage: b.avatarUrl != null
                                      ? NetworkImage(b.avatarUrl!)
                                      : null,
                                  child: b.avatarUrl != null
                                      ? null
                                      : Text(
                                          b.fullName.isNotEmpty
                                              ? b.fullName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 64,
                                  child: Text(
                                    b.fullName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Vorschläge zu deinen Sportzeiten',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (matched.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Aktuell gibt es noch keine passenden Leute zu deinen '
                          'Sportzeiten. Trag weitere Zeiten ein oder schau später nochmal vorbei.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.push('/new-activity'),
                          child: const Text('Sportzeit eintragen'),
                        ),
                      ],
                    ),
                  )
                else
                  ...matched.map((m) {
                    final a = m.activity;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondaryLight,
                          child: Icon(a.sport.icon, color: AppColors.primary),
                        ),
                        title: Text('${a.sport.label} · ${a.dayLabel}'),
                        subtitle: Text(a.timeRangeLabel),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${m.matchCount}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        onTap: () => context.push('/matches/${a.id}'),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
