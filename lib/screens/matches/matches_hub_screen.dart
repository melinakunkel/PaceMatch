import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/buddy.dart';
import '../../models/group.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../services/activity_service.dart';
import '../../services/block_service.dart';
import '../../services/circle_controller.dart';
import '../../services/group_service.dart';
import '../../services/like_service.dart';
import '../../services/match_notifier.dart';
import '../../services/match_service.dart';
import '../../services/profile_service.dart';
import '../../router/route_observer.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import 'likes_received_sheet.dart';

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

/// One line of "Deine Woche".
class _WeekItem {
  _WeekItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final DateTime date;
  final String title;
  final String subtitle;
  final String route;
}

class _HubData {
  _HubData({
    required this.groups,
    required this.unassignedBuddies,
    required this.myActivities,
    this.week = const [],
    this.likesReceived = const [],
    this.pendingSent = const [],
  });
  final List<_ActivityGroup> groups;
  final List<Activity> myActivities;

  /// "Wer hat dich geliked" — waiting for my like back.
  final List<PendingLike> likesReceived;

  /// My likes still waiting for an answer (with my sport time).
  final List<PendingLike> pendingSent;

  /// The next 7 days: sport times with buddies, and meetups set in chats.
  final List<_WeekItem> week;

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

  @override
  void initState() {
    super.initState();
    _future = _load();
    MatchNotifier.markSeen();
    CircleController.active.addListener(_onCircleChanged);
  }

  void _onCircleChanged() => _refresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    CircleController.active.removeListener(_onCircleChanged);
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
    // Identical sport times (saved twice by accident) count once — else
    // every buddy shows up once per copy.
    final seenSlots = <String>{};
    final activities = [
      for (final a in await _activityService.getMyActivities(
        userId,
        circleId: CircleController.active.value?.id,
      ))
        if (seenSlots.add(a.slotKey)) a,
    ];
    final activityIds = activities.map((a) => a.id).toSet();
    final likesFuture = _loadLikesReceived();
    final chatsFuture = _groupService
        .getMyGroups(userId)
        .catchError((Object _) => <SportGroup>[]);
    // Everyone who fits each sport time (liked or not), who I've liked, and
    // my buddies — all loading at the same time.
    final fitsFuture = _matchService.findMatchesForAll(
      activities,
      includeLiked: true,
    );
    // One read of my sent likes: "already liked" for the suggestions and
    // "Du wartest auf Antwort" below.
    final sentFuture = _likeService.getSentLikes();
    final buddies = await _likeService.getBuddies();
    final buddyProfiles = await _profileService.getProfilesByIds(
      buddies.map((b) => b.userId).toList(),
    );
    final fitsByActivity = await fitsFuture;
    final sent = await sentFuture;
    final liked = {for (final l in sent) l.userId};
    // New suggestions: fits, but not liked yet.
    final candidatesByActivity = {
      for (final e in fitsByActivity.entries)
        e.key: e.value.where((c) => !liked.contains(c.profile.id)).toList(),
    };
    final profilesById = {for (final p in buddyProfiles) p.id: p};
    final buddiesByActivity = <String, List<Profile>>{};
    final unassignedBuddies = <Profile>[];
    for (final b in buddies) {
      final profile = profilesById[b.userId];
      if (profile == null) continue;
      // A buddy shows at every sport time of mine they fit — plus the one
      // the like was made for. A like without a usable activity_id (missing
      // or since deleted) and no fitting time is still a real mutual match,
      // so it goes in the unassigned bucket instead of vanishing.
      final ids = {
        if (b.activityId != null && activityIds.contains(b.activityId))
          b.activityId!,
        for (final e in fitsByActivity.entries)
          if (e.value.any((c) => c.profile.id == b.userId)) e.key,
      };
      if (ids.isEmpty) {
        unassignedBuddies.add(profile);
      } else {
        for (final id in ids) {
          (buddiesByActivity[id] ??= []).add(profile);
        }
      }
    }

    final shown = activities.where(
      (a) =>
          (candidatesByActivity[a.id]?.isNotEmpty ?? false) ||
          (buddiesByActivity[a.id]?.isNotEmpty ?? false),
    );
    final results = await Future.wait(
      shown.map((a) async {
        final activityBuddies = buddiesByActivity[a.id] ?? [];
        // A group chat only makes sense with at least two buddies — with
        // one, it's simply the private chat.
        final groupId = activityBuddies.length < 2
            ? null
            : await _groupService.findGroupIdForActivity(a.id);
        return _ActivityGroup(
          activity: a,
          candidateCount: candidatesByActivity[a.id]?.length ?? 0,
          buddies: activityBuddies,
          groupId: groupId,
        );
      }),
    );
    results.sort(
      (x, y) => x.activity.nextOccurrence.compareTo(y.activity.nextOccurrence),
    );
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    bool thisWeek(DateTime d) => d.isAfter(now) && d.isBefore(weekEnd);
    final chats = await chatsFuture;
    // Only people I'm actually in touch with: deleting the chat takes them
    // out of "Deine Woche" (they stay a Sportbuddy).
    final chatPartners = {
      for (final c in chats)
        if (c.isDirect && c.partner != null) c.partner!.id,
    };
    final meetups = [
      for (final c in chats)
        if (c.meetingTime != null && thisWeek(c.meetingTime!.toLocal())) c,
    ];
    // A buddy whose chat already has a meetup this week shows once — as
    // that meetup.
    final withMeetup = {
      for (final c in meetups)
        if (c.isDirect && c.partner != null) c.partner!.id,
    };
    final week = <_WeekItem>[
      for (final g in results)
        if (thisWeek(g.activity.nextOccurrence))
          if (g.buddies
                  .where(
                    (b) =>
                        chatPartners.contains(b.id) &&
                        !withMeetup.contains(b.id),
                  )
                  .toList()
              case final inTouch when inTouch.isNotEmpty)
            _WeekItem(
              date: g.activity.nextOccurrence,
              title: g.activity.sport.label,
              subtitle: t('week.with', {
                'names': inTouch.map((b) => b.firstName).join(', '),
              }),
              route: '/matches/${g.activity.id}',
            ),
      for (final chat in meetups)
        _WeekItem(
          date: chat.meetingTime!.toLocal(),
          title: chat.displayName,
          subtitle: t('week.meetup'),
          route: '/group/${chat.id}',
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return _HubData(
      groups: results,
      unassignedBuddies: unassignedBuddies,
      myActivities: activities,
      week: week,
      likesReceived: await likesFuture,
      pendingSent: await _pendingSent(
        sent,
        buddyIds: {for (final b in buddies) b.userId},
        mine: activities,
      ),
    );
  }

  /// My likes still waiting for an answer, for the active Kreis — without
  /// blocked, suspended or paused people (same rules as everywhere else).
  Future<List<PendingLike>> _pendingSent(
    List<LikeRecord> sent, {
    required Set<String> buddyIds,
    required List<Activity> mine,
  }) async {
    final mineById = {for (final a in mine) a.id: a};
    final open = [
      for (final l in sent)
        if (!buddyIds.contains(l.userId) &&
            // A like made for a sport time of another Kreis belongs there.
            (l.activityId == null || mineById.containsKey(l.activityId)))
          l,
    ];
    if (open.isEmpty) return [];
    try {
      final results = await Future.wait([
        _profileService.getProfilesByIds(open.map((l) => l.userId).toList()),
        BlockService().blockedUserIds(),
      ]);
      final blocked = results[1] as Set<String>;
      final profileById = {
        for (final p in results[0] as List<Profile>)
          if (!p.isSuspended && !p.isPaused && !blocked.contains(p.id)) p.id: p,
      };
      return [
        for (final l in open)
          if (profileById[l.userId] != null)
            PendingLike(
              profile: profileById[l.userId]!,
              activity: mineById[l.activityId],
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _openPendingSent(_HubData data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PendingSentSheet(likes: data.pendingSent),
    );
    // However it was closed (button, swipe down): show what's changed.
    if (mounted) _refresh();
  }

  Future<List<PendingLike>> _loadLikesReceived() async {
    final likes = await _likeService.getLikesReceived();
    if (likes.isEmpty) return [];
    final profiles = await _profileService.getProfilesByIds(
      likes.map((l) => l.userId).toList(),
    );
    final activities = await _activityService.getActivitiesByIds(
      likes.map((l) => l.activityId).whereType<String>().toList(),
    );
    final profileById = {for (final p in profiles) p.id: p};
    final activityById = {for (final a in activities) a.id: a};
    return [
      for (final l in likes)
        if (profileById[l.userId] != null)
          PendingLike(
            profile: profileById[l.userId]!,
            activity: activityById[l.activityId],
          ),
    ];
  }

  Future<void> _openLikesReceived(_HubData data) async {
    final result = await showModalBottomSheet<LikeBackResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LikesReceivedSheet(
        likes: data.likesReceived,
        myActivities: data.myActivities,
      ),
    );
    if (!mounted) return;
    _refresh();
    if (result == null) return;
    final chat = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('likes.matchTitle')),
        content: Text(t('likes.matchBody', {'name': result.profile.firstName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.close')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('matchesHub.message')),
          ),
        ],
      ),
    );
    if (chat == true && mounted) {
      await _openDirectChat(result.profile, activity: result.myActivity);
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
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
                    ? t('matchesHub.pickForNewChat')
                    : t('matchesHub.pickForExistingChat'),
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
                  title: Text(b.firstName),
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
                      ? t('matchesHub.createGroupChat')
                      : t('discover.openChat'),
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
              '${activity.sport.label} · ${activity.locationLabel ?? activity.dayLabel}',
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
        SnackBar(
          content: Text(t('matchesHub.chatCreateFailed', {'error': '$e'})),
        ),
      );
    }
  }

  /// My private chat with [buddy] — for [activity]'s meetup when given.
  Future<void> _openDirectChat(Profile buddy, {Activity? activity}) async {
    try {
      final groupId = await _groupService.openDirectChat(
        myId: SupabaseService.currentUserId!,
        otherUserId: buddy.id,
        sport: activity?.sport ?? SportType.sonstige,
        meetingPoint: activity?.locationName,
        latitude: activity?.latitude,
        longitude: activity?.longitude,
        meetingTime: activity?.nextOccurrence,
        activityId: activity?.id,
        isMatch: true,
      );
      if (!mounted) return;
      context.push('/group/$groupId');
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('matchesHub.chatCreateFailed', {'error': '$e'})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2,
      title: t('matchesHub.title'),
      body: FutureBuilder<_HubData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data?.groups ?? [];
          final unassignedBuddies = snapshot.data?.unassignedBuddies ?? [];
          final likesReceived = snapshot.data?.likesReceived ?? [];
          final pendingSent = snapshot.data?.pendingSent ?? [];
          if (groups.isEmpty &&
              unassignedBuddies.isEmpty &&
              likesReceived.isEmpty &&
              pendingSent.isEmpty) {
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
                    t('matchesHub.empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.push('/new-activity'),
                      child: Text(t('matchesHub.addActivity')),
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
                if (likesReceived.isNotEmpty) _buildLikesCard(snapshot.data!),
                if (pendingSent.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondaryLight,
                        child: Icon(
                          Icons.hourglass_top,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        pendingSent.length == 1
                            ? t('likes.pendingCardOne')
                            : t('likes.pendingCard', {
                                'count': '${pendingSent.length}',
                              }),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(t('likes.pendingCardSubtitle')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPendingSent(snapshot.data!),
                    ),
                  ),
                if (snapshot.data!.week.isNotEmpty)
                  _buildWeekCard(snapshot.data!.week),
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

  Widget _buildLikesCard(_HubData data) {
    final likes = data.likesReceived;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.secondaryLight,
          child: Icon(Icons.favorite, color: AppColors.primary),
        ),
        title: Text(
          likes.length == 1
              ? t('likes.cardOne', {'name': likes.first.profile.firstName})
              : t('likes.cardMany', {'count': '${likes.length}'}),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(t('likes.cardSubtitle')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openLikesReceived(data),
      ),
    );
  }

  Widget _buildWeekCard(List<_WeekItem> items) {
    String when(DateTime d) =>
        '${weekdayLabels[d.weekday - 1]} '
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}. · '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.secondaryLight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  t('week.title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${when(item.date)} · ${item.title}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(item.route),
              ),
          ],
        ),
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
              t('matchesHub.moreBuddies'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              t('matchesHub.unassignedDesc'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...buddies.map((b) => _buddyRow(b, () => _openDirectChat(b))),
          ],
        ),
      ),
    );
  }

  /// One buddy with a button into our private chat.
  Widget _buddyRow(Profile b, VoidCallback onMessage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${b.id}'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondaryLight,
              backgroundImage: b.avatarUrl != null
                  ? NetworkImage(b.avatarUrl!)
                  : null,
              child: b.avatarUrl != null
                  ? null
                  : Text(
                      b.fullName.isNotEmpty ? b.fullName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(b.firstName)),
          OutlinedButton.icon(
            // Theme's default minimumSize is full-width (Size.fromHeight) —
            // inside a Row that gets unbounded incoming width and silently
            // breaks layout, so this needs its own compact minimumSize.
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: Text(t('matchesHub.message')),
          ),
        ],
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
              ...g.buddies.map(
                (b) => _buddyRow(b, () => _openDirectChat(b, activity: a)),
              ),
              // With two or more buddies for the same time, they can also
              // meet as a group — a separate group chat, on purpose.
              if (g.buddies.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => _openGroupSheet(g),
                    icon: const Icon(Icons.groups_outlined, size: 20),
                    label: Text(
                      g.groupId == null
                          ? t('matchesHub.groupChatAll')
                          : t('matchesHub.groupChat'),
                    ),
                  ),
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
                      g.candidateCount == 1
                          ? t('matchesHub.moreSuggestionsOne')
                          : t('matchesHub.moreSuggestions', {
                              'count': '${g.candidateCount}',
                            }),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/matches/${a.id}'),
                    child: Text(t('matchesHub.view')),
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
