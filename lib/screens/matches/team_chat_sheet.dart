import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../services/group_service.dart';
import '../../services/like_service.dart';
import '../../services/match_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// For doubles / 2-vs-2: one group chat with the Sportbuddys found for
/// this sport time, instead of juggling several private chats.
class TeamChatSheet extends StatefulWidget {
  const TeamChatSheet({super.key, required this.activity});

  final Activity activity;

  @override
  State<TeamChatSheet> createState() => _TeamChatSheetState();
}

class _TeamChatSheetState extends State<TeamChatSheet> {
  List<Profile> _buddies = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Buddys liked for this sport time, or who simply fit it.
      final fits =
          (await MatchService().findMatchesForAll([
            widget.activity,
          ], includeLiked: true))[widget.activity.id] ??
          [];
      final fitIds = fits.map((c) => c.profile.id).toSet();
      final buddyIds = (await LikeService().getBuddies())
          .where(
            (b) =>
                b.activityId == widget.activity.id || fitIds.contains(b.userId),
          )
          .map((b) => b.userId)
          .toSet();
      final profiles = <Profile>[];
      for (final id in buddyIds) {
        profiles.add(await ProfileService().getProfile(id));
      }
      _buddies = profiles;
      _selected.addAll(buddyIds.take(widget.activity.playersWanted));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    setState(() => _creating = true);
    try {
      final a = widget.activity;
      final groups = GroupService();
      final group = await groups.createGroup(
        createdBy: myId,
        sport: a.sport,
        name:
            '${a.sport.label} · ${a.isRecurring ? a.dayLabel : a.specificDateLabel}',
        meetingPoint: a.locationName,
        latitude: a.latitude,
        longitude: a.longitude,
        meetingTime: a.nextOccurrence,
        activityId: a.id,
      );
      for (final id in _selected) {
        await groups.joinGroup(groupId: group.id, userId: id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/group/${group.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('team.title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t('team.subtitle', {'count': '${widget.activity.playersWanted}'}),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_buddies.length < 2)
              Text(
                t('team.notEnough'),
                style: TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              for (final p in _buddies)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(p.id),
                  title: Text(p.firstName),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(p.id);
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _creating || _selected.length < 2 ? null : _create,
                child: Text(
                  t('team.create', {'count': '${_selected.length + 1}'}),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
