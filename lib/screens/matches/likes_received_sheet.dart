import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../services/like_service.dart';
import '../../theme/app_theme.dart';

/// A like waiting for an answer, with the sport time it was made for —
/// theirs for a like I received, mine for one I sent.
class PendingLike {
  const PendingLike({required this.profile, this.activity});

  final Profile profile;
  final Activity? activity;
}

/// What happened in the sheet: a new match (and with which of my sport
/// times, if one fits), or nothing.
class LikeBackResult {
  const LikeBackResult(this.profile, this.myActivity);

  final Profile profile;
  final Activity? myActivity;
}

/// "Wer hat dich geliked": like back in one tap — that's an instant match.
class LikesReceivedSheet extends StatefulWidget {
  const LikesReceivedSheet({
    super.key,
    required this.likes,
    required this.myActivities,
  });

  final List<PendingLike> likes;
  final List<Activity> myActivities;

  @override
  State<LikesReceivedSheet> createState() => _LikesReceivedSheetState();
}

class _LikesReceivedSheetState extends State<LikesReceivedSheet> {
  String? _busyId;

  /// My sport time that fits theirs best — same sport and day — so the
  /// match lands on the right Sportzeit in the Buddys tab.
  Activity? _myFittingActivity(Activity? theirs) {
    if (theirs == null) return null;
    final sameSport = widget.myActivities
        .where((a) => a.sport == theirs.sport)
        .toList();
    for (final a in sameSport) {
      if (a.dayOfWeek == theirs.dayOfWeek) return a;
    }
    return sameSport.isEmpty ? null : sameSport.first;
  }

  Future<void> _likeBack(PendingLike like) async {
    setState(() => _busyId = like.profile.id);
    final mine = _myFittingActivity(like.activity);
    try {
      final mutual = await LikeService().like(
        toUser: like.profile.id,
        activityId: mine?.id,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pop(mutual ? LikeBackResult(like.profile, mine) : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          children: [
            Text(
              t('likes.sheetTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t('likes.sheetSubtitle'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final like in widget.likes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push('/profile/${like.profile.id}'),
                  leading: _Avatar(like.profile),
                  title: Text(like.profile.firstName),
                  subtitle: like.activity == null
                      ? null
                      : Text(like.activity!.summaryLabel),
                  trailing: _busyId == like.profile.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                          ),
                          icon: const Icon(Icons.favorite, size: 16),
                          label: Text(t('likes.likeBack')),
                          onPressed: _busyId == null
                              ? () => _likeBack(like)
                              : null,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Du wartest auf Antwort": my likes that aren't mutual yet — hidden from
/// suggestions, so they can be taken back here (the person then shows up
/// as a suggestion again).
class PendingSentSheet extends StatefulWidget {
  const PendingSentSheet({super.key, required this.likes});

  /// Here [PendingLike.activity] is my own sport time.
  final List<PendingLike> likes;

  @override
  State<PendingSentSheet> createState() => _PendingSentSheetState();
}

class _PendingSentSheetState extends State<PendingSentSheet> {
  late final List<PendingLike> _likes = [...widget.likes];
  String? _busyId;

  Future<void> _undo(PendingLike like) async {
    setState(() => _busyId = like.profile.id);
    try {
      final likes = LikeService();
      await likes.unlike(like.profile.id);
      // unlike_user keeps a like that has become mutual in the meantime —
      // say so instead of pretending it was taken back.
      final nowBuddy = (await likes.getBuddies()).any(
        (b) => b.userId == like.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _likes.remove(like);
        _busyId = null;
      });
      if (nowBuddy) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('likes.undoTooLate', {'name': like.profile.firstName}),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          children: [
            Text(
              t('likes.pendingTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t('likes.pendingSubtitle'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_likes.isEmpty)
              Text(
                t('likes.pendingEmpty'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            for (final like in _likes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push('/profile/${like.profile.id}'),
                  leading: _Avatar(like.profile),
                  title: Text(like.profile.firstName),
                  subtitle: like.activity == null
                      ? null
                      : Text(like.activity!.summaryLabel),
                  trailing: _busyId == like.profile.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _busyId == null ? () => _undo(like) : null,
                          child: Text(t('likes.undo')),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;
    return CircleAvatar(
      backgroundColor: AppColors.secondaryLight,
      backgroundImage: url == null ? null : NetworkImage(url),
      child: url == null
          ? Text(
              profile.firstName.isEmpty
                  ? '?'
                  : profile.firstName[0].toUpperCase(),
              style: TextStyle(color: AppColors.primary),
            )
          : null,
    );
  }
}
