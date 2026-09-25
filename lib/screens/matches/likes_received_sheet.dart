import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../services/like_service.dart';
import '../../theme/app_theme.dart';

/// Someone waiting for my like back, with the sport time they liked me for.
class PendingLike {
  const PendingLike({required this.profile, this.theirActivity});

  final Profile profile;
  final Activity? theirActivity;
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
    final mine = _myFittingActivity(like.theirActivity);
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
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    backgroundImage: like.profile.avatarUrl == null
                        ? null
                        : NetworkImage(like.profile.avatarUrl!),
                    child: like.profile.avatarUrl == null
                        ? Text(
                            like.profile.firstName.isEmpty
                                ? '?'
                                : like.profile.firstName[0].toUpperCase(),
                            style: TextStyle(color: AppColors.primary),
                          )
                        : null,
                  ),
                  title: Text(like.profile.firstName),
                  subtitle: like.theirActivity == null
                      ? null
                      : Text(
                          '${like.theirActivity!.sport.label} · '
                          '${like.theirActivity!.isRecurring ? like.theirActivity!.dayShortLabel : like.theirActivity!.specificDateLabel} · '
                          '${like.theirActivity!.timeRangeLabel}',
                        ),
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
