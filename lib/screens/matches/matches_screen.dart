import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/match_candidate.dart';
import '../../models/profile.dart';
import '../../models/user_sport.dart';
import '../../services/activity_service.dart';
import '../../services/like_service.dart';
import '../../services/match_service.dart';
import '../../services/match_notifier.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/activity_stats.dart';
import '../../widgets/venue_status_badge.dart';
import '../../widgets/verified_badge.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _activityService = ActivityService();
  final _matchService = MatchService();
  final _profileService = ProfileService();
  final _likeService = LikeService();

  Activity? _activity;
  List<MatchCandidate> _candidates = [];
  Map<String, UserSport> _theirSports = {};
  int _topIndex = 0;
  bool _celebrating = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await _activityService.getActivityById(
        widget.activityId,
      );
      final candidates = await _matchService.findMatches(activity);
      final theirSports = activity.sport.usesPace
          ? <String, UserSport>{}
          : await _profileService.getUserSportsForUsers(
              candidates.map((c) => c.profile.id).toList(),
              activity.sport,
            );
      setState(() {
        _activity = activity;
        _candidates = candidates;
        _theirSports = theirSports;
        _topIndex = 0;
      });
    } catch (e) {
      setState(() => _error = 'Sportbuddys konnten nicht geladen werden.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _swipe(MatchCandidate candidate, bool liked) async {
    setState(() => _topIndex++);
    if (!liked) return;
    // Every right-swipe must reach the server, even if a previous one
    // (from a fast double-swipe) is still in flight — this used to bail
    // out early via a busy check and silently drop the like, so a quick
    // second swipe never got recorded and a mutual connection could never
    // fire.
    try {
      final me = SupabaseService.currentUserId!;
      final mutual = await _likeService.like(
        fromUser: me,
        toUser: candidate.profile.id,
        activityId: _activity?.id,
      );
      if (!mounted || !mutual) return;
      MatchNotifier.refresh();
      // Only guard the celebration dialog against overlapping popups if two
      // connections land back to back.
      if (_celebrating) return;
      _celebrating = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MatchCelebrationDialog(profile: candidate.profile),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Da ging etwas schief: $e')));
    } finally {
      _celebrating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _activity == null
              ? 'Passende Leute'
              : '${_activity!.sport.label} · ${_activity!.dayLabel}',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final activity = _activity!;
    final remaining = _candidates.length - _topIndex;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(activity.timeRangeLabel),
              const SizedBox(width: 16),
              Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(activity.locationName ?? 'Ort flexibel')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _candidates.isEmpty
                  ? 'Noch keine passenden Leute gefunden.'
                  : remaining > 0
                  ? 'Wisch durch, wer zu dir passt.'
                  : 'Das waren alle für heute.',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _candidates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Sobald jemand eine ähnliche Sportzeit einträgt, '
                      'erscheint er oder sie hier.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : remaining <= 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Keine weiteren Vorschläge — schau später nochmal vorbei.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Stack(
                    children: [
                      for (
                        var i =
                            (_topIndex + 2).clamp(0, _candidates.length) - 1;
                        i >= _topIndex;
                        i--
                      )
                        if (i == _topIndex)
                          _SwipeCard(
                            key: ValueKey(_candidates[i].profile.id),
                            onSwiped: (liked) => _swipe(_candidates[i], liked),
                            child: _MatchCard(
                              candidate: _candidates[i],
                              theirSport:
                                  _theirSports[_candidates[i].profile.id],
                            ),
                          )
                        else
                          Transform.scale(
                            scale: 0.95,
                            child: Opacity(
                              opacity: 0.6,
                              child: _MatchCard(
                                candidate: _candidates[i],
                                theirSport:
                                    _theirSports[_candidates[i].profile.id],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
        ),
        if (_candidates.isNotEmpty && remaining > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundActionButton(
                  icon: Icons.close,
                  color: AppColors.danger,
                  onPressed: () => _swipe(_candidates[_topIndex], false),
                ),
                const SizedBox(width: 32),
                _RoundActionButton(
                  icon: Icons.favorite,
                  color: AppColors.secondary,
                  onPressed: () => _swipe(_candidates[_topIndex], true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: color, width: 2)),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

/// Wraps [child] with drag-to-swipe: drag far enough left/right and
/// [onSwiped] fires with whether it was a "like" (right) or "pass" (left).
class _SwipeCard extends StatefulWidget {
  const _SwipeCard({super.key, required this.child, required this.onSwiped});

  final Widget child;
  final void Function(bool liked) onSwiped;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  Offset _drag = Offset.zero;
  static const _threshold = 110.0;

  @override
  Widget build(BuildContext context) {
    final angle = (_drag.dx / 300).clamp(-0.5, 0.5);
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _drag += details.delta),
      onPanEnd: (details) {
        if (_drag.dx.abs() > _threshold) {
          widget.onSwiped(_drag.dx > 0);
        } else {
          setState(() => _drag = Offset.zero);
        }
      },
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            children: [
              widget.child,
              if (_drag.dx > 20)
                Positioned(
                  top: 20,
                  left: 20,
                  child: _StampBadge(label: 'LIKE', color: AppColors.secondary),
                ),
              if (_drag.dx < -20)
                Positioned(
                  top: 20,
                  right: 20,
                  child: _StampBadge(label: 'NOPE', color: AppColors.danger),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StampBadge extends StatelessWidget {
  const _StampBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.candidate, required this.theirSport});

  final MatchCandidate candidate;
  final UserSport? theirSport;

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    return SizedBox.expand(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.secondaryLight,
                    child: profile.avatarUrl != null
                        ? Image.network(profile.avatarUrl!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              profile.fullName.isNotEmpty
                                  ? profile.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 64,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/profile/${profile.id}'),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => context.push('/profile/${profile.id}'),
                          child: Text(
                            [
                              profile.fullName,
                              if (profile.age != null) '${profile.age}',
                            ].join(', '),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 16),
                      ],
                      const Spacer(),
                      _MatchBadge(percent: candidate.matchPercent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (profile.gender != null) profile.gender!,
                      candidate.theirActivity.timeRangeLabel,
                      candidate.theirActivity.locationName ?? 'Ort flexibel',
                    ].join(' · '),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VenueStatusBadge(activity: candidate.theirActivity),
                      Builder(
                        builder: (context) {
                          final stats = activityStatsLabel(
                            candidate.theirActivity,
                            theirSport,
                          );
                          if (stats == null) return const SizedBox.shrink();
                          return Text(
                            stats,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MatchCelebrationDialog extends StatelessWidget {
  const _MatchCelebrationDialog({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, color: AppColors.secondary, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Ihr seid jetzt Sportbuddys!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.fullName} und du wollt beide zusammen trainieren.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.secondaryLight,
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl != null
                  ? null
                  : Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/matches');
                },
                child: const Text('Zu deinen Sportbuddys'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Weiter swipen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
