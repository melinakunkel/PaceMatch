import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../services/activity_service.dart';
import '../../services/group_service.dart';
import '../../services/like_service.dart';
import '../../services/match_notifier.dart';
import '../../services/match_service.dart';
import '../../services/profile_service.dart';
import '../../router/route_observer.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

/// One of the user's own activities, with who they've mutually connected
/// with for it (real Sportbuddys) and how many more candidates are still
/// worth swiping through.
class _ActivityGroup {
  _ActivityGroup({
    required this.activity,
    required this.candidateCount,
    required this.buddies,
    required this.groupId,
  });
  final Activity activity;
  final int candidateCount;
  final List<Profile> buddies;
  final String? groupId;
}

class _HubData {
  _HubData({required this.groups, required this.unassignedBuddies});
  final List<_ActivityGroup> groups;

  /// Confirmed Sportbuddys whose like wasn't tied to one of the user's
  /// current activities (e.g. the activity_id is missing or the activity
  /// was since deleted) — still real matches, just not attributable to one
  /// specific Sportzeit, so they get their own section instead of silently
  /// disappearing.
  final List<Profile> unassignedBuddies;
}

/// Sportbuddys tab: your own activities, each with its real next date and
/// who you've actually connected with for it — the unit "Sportzeit" is the
/// organizing principle, not the person.
class MatchesHubScreen extends StatefulWidget {
  const MatchesHubScreen({super.key});

  @override
  State<MatchesHubScreen> createState() => _MatchesHubScreenState();
}

class _MatchesHubScreenState extends State<MatchesHubScreen> with RouteAware {
  final _activityService = ActivityService();
  final _matchService = MatchService();
  final _likeService = LikeService();
  final _profileService = ProfileService();
  final _groupService = GroupService();

  late Future<_HubData> _future;
  final Map<String, String?> _chatByUnassignedBuddy = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
    MatchNotifier.markSeen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when a screen pushed on top of this one (swiping candidates,
  /// viewing a profile) gets popped and this hub becomes visible again —
  /// without this, a fresh match made while swiping wouldn't show up here
  /// until a manual pull-to-refresh, since this screen's state isn't
  /// recreated just by navigating back to it.
  @override
  void didPopNext() {
    _refresh();
    MatchNotifier.markSeen();
  }

  Future<_HubData> _load() async {
    final userId = SupabaseService.currentUserId!;
    final activities = await _activityService.getMyActivities(userId);
    final activityIds = activities.map((a) => a.id).toSet();
    final buddies = await _likeService.getBuddies(userId);
    final buddyProfiles = await _profileService.getProfilesByIds(
      buddies.map((b) => b.userId).toList(),
    );
    final profilesById = {for (final p in buddyProfiles) p.id: p};
    final buddiesByActivity = <String, List<Profile>>{};
    final unassignedBuddies = <Profile>[];
    for (final b in buddies) {
      final profile = profilesById[b.userId];
      if (profile == null) continue;
      // A buddy's like might not carry a usable activity_id (missing, or
      // pointing at an activity that's since been deleted) — still a real
      // mutual match, so it goes in the unassigned bucket instead of
      // vanishing.
      if (b.activityId != null && activityIds.contains(b.activityId)) {
        (buddiesByActivity[b.activityId!] ??= []).add(profile);
      } else {
        unassignedBuddies.add(profile);
      }
    }

    final unassignedChatMap = <String, String?>{};
    for (final p in unassignedBuddies) {
      unassignedChatMap[p.id] = await _groupService.findSharedGroupId(p.id);
    }
    _chatByUnassignedBuddy
      ..clear()
      ..addAll(unassignedChatMap);

    final results = <_ActivityGroup>[];
    for (final a in activities) {
      final candidates = await _matchService.findMatches(a);
      final activityBuddies = buddiesByActivity[a.id] ?? [];
      if (candidates.isEmpty && activityBuddies.isEmpty) continue;
      final groupId = activityBuddies.isEmpty
          ? null
          : await _groupService.findGroupIdForActivity(a.id);
      results.add(
        _ActivityGroup(
          activity: a,
          candidateCount: candidates.length,
          buddies: activityBuddies,
          groupId: groupId,
        ),
      );
    }
    results.sort(
      (x, y) => x.activity.nextOccurrence.compareTo(y.activity.nextOccurrence),
    );
    return _HubData(groups: results, unassignedBuddies: unassignedBuddies);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  static String _dateLabel(Activity a) {
    final d = a.nextOccurrence;
    return '${weekdayLabels[d.weekday - 1]}, '
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> _openGroupSheet(_ActivityGroup group) async {
    final selected = {for (final b in group.buddies) b.id};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${group.activity.sport.label} · ${_dateLabel(group.activity)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.groupId == null
                    ? 'Wähl aus, wen du zum Gruppenchat hinzufügen willst.'
                    : 'Wähl aus, wen du zum bestehenden Chat hinzufügen willst.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...group.buddies.map(
                (b) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(b.id),
                  onChanged: (v) => setSheetState(() {
                    if (v == true) {
                      selected.add(b.id);
                    } else {
                      selected.remove(b.id);
                    }
                  }),
                  secondary: CircleAvatar(
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
                            style: TextStyle(color: AppColors.primary),
                          ),
                  ),
                  title: Text(b.fullName),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _createOrJoinGroup(group, selected.toList());
                      },
                child: Text(
                  group.groupId == null
                      ? 'Gruppenchat erstellen'
                      : 'Chat öffnen',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createOrJoinGroup(
    _ActivityGroup group,
    List<String> buddyIds,
  ) async {
    try {
      final me = SupabaseService.currentUserId!;
      final activity = group.activity;
      String groupId;
      if (group.groupId != null) {
        groupId = group.groupId!;
      } else {
        final created = await _groupService.createGroup(
          createdBy: me,
          sport: activity.sport,
          name:
              '${activity.sport.label} · ${activity.locationName ?? activity.dayLabel}',
          meetingPoint: activity.locationName,
          latitude: activity.latitude,
          longitude: activity.longitude,
          meetingTime: activity.nextOccurrence,
          activityId: activity.id,
          isMatch: true,
        );
        groupId = created.id;
      }
      for (final id in buddyIds) {
        await _groupService.joinGroup(groupId: groupId, userId: id);
      }
      if (!mounted) return;
      context.push('/group/$groupId');
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat konnte nicht erstellt werden: $e')),
      );
    }
  }

  Future<void> _startChatWithUnassignedBuddy(Profile buddy) async {
    final existing = _chatByUnassignedBuddy[buddy.id];
    try {
      String groupId;
      if (existing != null) {
        groupId = existing;
      } else {
        final me = SupabaseService.currentUserId!;
        final created = await _groupService.createGroup(
          createdBy: me,
          sport: SportType.sonstige,
          name: 'Sportbuddy: ${buddy.fullName}',
          isMatch: true,
        );
        await _groupService.joinGroup(groupId: created.id, userId: buddy.id);
        groupId = created.id;
      }
      if (!mounted) return;
      context.push('/group/$groupId');
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat konnte nicht erstellt werden: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2,
      title: 'Sportbuddys',
      body: FutureBuilder<_HubData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data?.groups ?? [];
          final unassignedBuddies = snapshot.data?.unassignedBuddies ?? [];
          if (groups.isEmpty && unassignedBuddies.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aktuell gibt es noch keine passenden Leute zu deinen '
                    'Sportzeiten. Trag weitere Zeiten ein oder schau später nochmal vorbei.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.push('/new-activity'),
                      child: const Text('Sportzeit eintragen'),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (unassignedBuddies.isNotEmpty)
                  _buildUnassignedCard(unassignedBuddies),
                ...groups.map(_buildActivityCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnassignedCard(List<Profile> buddies) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weitere Sportbuddys',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Nicht mehr einer bestimmten Sportzeit zugeordnet.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...buddies.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
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
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b.fullName)),
                    OutlinedButton(
                      onPressed: () => _startChatWithUnassignedBuddy(b),
                      child: Text(
                        _chatByUnassignedBuddy[b.id] == null
                            ? 'Chat starten'
                            : 'Chat öffnen',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(_ActivityGroup g) {
    final a = g.activity;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.secondaryLight,
                  child: Icon(a.sport.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.sport.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_dateLabel(a)} · ${a.timeRangeLabel}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (g.buddies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        for (var i = 0; i < g.buddies.length.clamp(0, 4); i++)
                          Positioned(
                            left: i * 24.0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surface,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.secondaryLight,
                                backgroundImage: g.buddies[i].avatarUrl != null
                                    ? NetworkImage(g.buddies[i].avatarUrl!)
                                    : null,
                                child: g.buddies[i].avatarUrl != null
                                    ? null
                                    : Text(
                                        g.buddies[i].fullName.isNotEmpty
                                            ? g.buddies[i].fullName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: g.buddies.length.clamp(0, 4) * 24.0 + 4),
                  Expanded(
                    child: Text(
                      '${g.buddies.length} Sportbuddy${g.buddies.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _openGroupSheet(g),
                    child: Text(g.groupId == null ? 'Gruppenchat' : 'Chat'),
                  ),
                ],
              ),
            ],
            if (g.candidateCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${g.candidateCount} weitere Vorschläge',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/matches/${a.id}'),
                    child: const Text('Ansehen'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
