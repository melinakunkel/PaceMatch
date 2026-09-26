import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/match_candidate.dart';
import '../../models/profile.dart';
import '../../models/user_sport.dart';
import '../../services/activity_service.dart';
import '../../services/group_service.dart';
import '../../services/like_service.dart';
import '../../services/match_pass_service.dart';
import '../../services/match_service.dart';
import '../../services/match_notifier.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/activity_stats.dart';
import '../../utils/display_labels.dart';
import '../../utils/match_scoring.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/venue_status_badge.dart';
import '../../widgets/verified_badge.dart';
import 'no_matches_yet.dart';

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
  final _matchPassService = MatchPassService();
  final _groupService = GroupService();

  Activity? _activity;
  List<MatchCandidate> _candidates = [];
  Map<String, UserSport> _theirSports = {};

  /// Liked this session (right-swiped or liked from the list) — removed from
  /// [_pending] immediately so it can't be shown again without reloading.
  final Set<String> _likedThisSession = {};

  /// Passed on (left-swiped), loaded from and persisted to the server —
  /// unlike a like, this only ever affects [_swipeable]: the list view still
  /// shows a passed candidate, since only a like should hide someone for
  /// good. Passing is a "not now", not a permanent verdict.
  Set<String> _passedIds = {};

  bool _listView = false;
  bool _celebrating = false;
  bool _loading = true;
  String? _error;

  // "Same time"/"same pace" filters — a candidate only counts as a match
  // for these at all once their time overlap (and, for pace sports, pace
  // overlap) already passed [MatchService.findMatches]'s score > 0 cutoff,
  // so this threshold picks out the closer half of that overlap range
  // rather than merely "any overlap".
  static const _sameThreshold = 0.5;
  bool _filterSameTime = false;
  bool _filterSamePace = false;

  // Rewind state for the most recent swipe only (matches the standard
  // "undo last swipe" behavior in swipe apps, not a full history).
  MatchCandidate? _lastSwiped;
  bool _lastLiked = false;
  bool _lastPending = false;
  bool _lastMutual = false;

  bool get _canUndo => _lastSwiped != null && !_lastPending && !_lastMutual;

  /// Candidates still to decide on, before the same-time/same-pace filters
  /// — liked ones drop out immediately; passed ones stay so the list view
  /// can still offer them. Used to tell "you're out of candidates" apart
  /// from "the filters hid everyone".
  List<MatchCandidate> get _pendingUnfiltered => _candidates
      .where((c) => !_likedThisSession.contains(c.profile.id))
      .toList();

  bool _matchesFilters(MatchCandidate c) {
    final mine = _activity!;
    if (_filterSameTime &&
        timeOverlapRatio(
              mine.startTime,
              mine.endTime,
              c.theirActivity.startTime,
              c.theirActivity.endTime,
            ) <
            _sameThreshold) {
      return false;
    }
    if (_filterSamePace &&
        paceOverlapRatio(
              mine.paceMin,
              mine.paceMax,
              c.theirActivity.paceMin,
              c.theirActivity.paceMax,
            ) <
            _sameThreshold) {
      return false;
    }
    return true;
  }

  /// Candidates still to decide on — [_pendingUnfiltered] narrowed by the
  /// same-time/same-pace filters.
  List<MatchCandidate> get _pending =>
      _pendingUnfiltered.where(_matchesFilters).toList();

  /// What the swipe view shows — [_pending] minus anyone already passed on.
  List<MatchCandidate> get _swipeable =>
      _pending.where((c) => !_passedIds.contains(c.profile.id)).toList();

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
      final passedIds = await _matchPassService.passedUserIdsForActivity(
        activity.id,
      );
      setState(() {
        _activity = activity;
        _candidates = candidates;
        _theirSports = theirSports;
        _passedIds = passedIds;
        _likedThisSession.clear();
        _lastSwiped = null;
      });
    } catch (e) {
      setState(() => _error = t('matches.loadFailed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens (or reuses) my private chat with [userId] for this activity —
  /// called right after a mutual match so the celebration dialog can open
  /// straight into the chat instead of sending the user on a detour through
  /// the Sportbuddys hub.
  Future<String?> _ensureGroupFor(String userId) async {
    final activity = _activity;
    if (activity == null) return null;
    try {
      return await _groupService.openDirectChat(
        myId: SupabaseService.currentUserId!,
        otherUserId: userId,
        sport: activity.sport,
        meetingPoint: activity.locationName,
        latitude: activity.latitude,
        longitude: activity.longitude,
        meetingTime: activity.nextOccurrence,
        activityId: activity.id,
        isMatch: true,
      );
    } catch (_) {
      // Best-effort — the celebration dialog falls back to the Hub if this
      // fails, so a chat can still be set up manually from there.
      return null;
    }
  }

  Future<void> _swipe(MatchCandidate candidate, bool liked) async {
    setState(() {
      if (liked) {
        _likedThisSession.add(candidate.profile.id);
      } else {
        _passedIds = {..._passedIds, candidate.profile.id};
      }
      _lastSwiped = candidate;
      _lastLiked = liked;
      _lastMutual = false;
      _lastPending = true;
    });
    if (!liked) {
      // Best-effort — a failed pass just means this candidate might come
      // back after a reload, not a broken swipe.
      try {
        await _matchPassService.recordPass(
          targetId: candidate.profile.id,
          activityId: widget.activityId,
        );
      } catch (_) {
        // ignore
      } finally {
        if (identical(_lastSwiped, candidate) && mounted) {
          setState(() => _lastPending = false);
        }
      }
      return;
    }
    // Every right-swipe must reach the server, even if a previous one
    // (from a fast double-swipe) is still in flight — this used to bail
    // out early via a busy check and silently drop the like, so a quick
    // second swipe never got recorded and a mutual connection could never
    // fire.
    try {
      final mutual = await _likeService.like(
        toUser: candidate.profile.id,
        activityId: _activity?.id,
      );
      if (!mounted) return;
      // Only this swipe's own pending/mutual flags — a faster later swipe
      // may already have replaced _lastSwiped by the time this resolves.
      if (identical(_lastSwiped, candidate)) {
        setState(() {
          _lastPending = false;
          _lastMutual = mutual;
        });
      }
      if (!mutual) return;
      MatchNotifier.refresh();
      final groupId = await _ensureGroupFor(candidate.profile.id);
      if (!mounted) return;
      // Only guard the celebration dialog against overlapping popups if two
      // connections land back to back.
      if (_celebrating) return;
      _celebrating = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MatchCelebrationDialog(
          profile: candidate.profile,
          groupId: groupId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('matches.somethingWentWrong', {'error': '$e'})),
        ),
      );
    } finally {
      _celebrating = false;
    }
  }

  /// Rewinds the most recent swipe — removes the like or pass that was
  /// recorded for it, unless it already became a mutual match.
  Future<void> _undo() async {
    if (!_canUndo) return;
    final candidate = _lastSwiped!;
    final wasLiked = _lastLiked;
    setState(() {
      if (wasLiked) {
        _likedThisSession.remove(candidate.profile.id);
      } else {
        _passedIds = {..._passedIds}..remove(candidate.profile.id);
      }
      _lastSwiped = null;
    });
    try {
      if (wasLiked) {
        await _likeService.unlike(candidate.profile.id);
      } else {
        await _matchPassService.removePass(
          targetId: candidate.profile.id,
          activityId: widget.activityId,
        );
      }
    } catch (_) {
      // Best-effort — worst case the decision just stays recorded.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/matches'),
        ),
        title: Text(
          _activity == null
              ? t('matches.title')
              : '${_activity!.sport.label} · ${_activity!.dayLabel}',
        ),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: Icon(_listView ? Icons.style_outlined : Icons.list),
              tooltip: _listView
                  ? t('matches.viewToggleSwipe')
                  : t('matches.viewToggleList'),
              onPressed: () => setState(() => _listView = !_listView),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              )
            : _listView
            ? _buildListBody()
            : _buildSwipeBody(),
      ),
    );
  }

  Widget _buildListBody() {
    final activity = _activity!;
    if (_candidates.isEmpty) return _buildNoMatchesYet(activity);
    final pending = _pending;
    final filteredOutEverything =
        pending.isEmpty && _pendingUnfiltered.isNotEmpty;
    return Column(
      children: [
        _buildHeader(activity),
        _buildFilterRow(activity),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _candidates.isEmpty
                  ? t('matches.noneFoundYet')
                  : _pendingUnfiltered.isEmpty
                  ? t('matches.allDoneForToday')
                  : filteredOutEverything
                  ? t('matches.noneMatchFilters')
                  : t('matches.listPrompt'),
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
                      t('matches.emptyHint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : pending.isEmpty
              ? _buildPendingEmptyState(filteredOutEverything)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: pending.length,
                  itemBuilder: (context, i) => _CandidateListTile(
                    candidate: pending[i],
                    theirSport: _theirSports[pending[i].profile.id],
                    onLike: () => _swipe(pending[i], true),
                  ),
                ),
        ),
      ],
    );
  }

  /// Filter chips for narrowing candidates down to (roughly) the same time
  /// and/or pace as [activity] — "same pace" only makes sense for
  /// pace-tracked sports, so it's hidden for e.g. Tennis/Wandern.
  Widget _buildFilterRow(Activity activity) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(t('matches.filterSameTime')),
            selected: _filterSameTime,
            onSelected: (v) => setState(() => _filterSameTime = v),
          ),
          if (activity.sport.usesPace)
            FilterChip(
              label: Text(t('matches.filterSamePace')),
              selected: _filterSamePace,
              onSelected: (v) => setState(() => _filterSamePace = v),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingEmptyState(bool filteredOutEverything) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filteredOutEverything
                  ? Icons.filter_alt_off_outlined
                  : Icons.check_circle_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              filteredOutEverything
                  ? t('matches.noneMatchFiltersHint')
                  : t('matches.noMoreSuggestions'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (filteredOutEverything) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _filterSameTime = false;
                  _filterSamePace = false;
                }),
                child: Text(t('matches.clearFilters')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesYet(Activity activity) {
    return Column(
      children: [
        _buildHeader(activity),
        const SizedBox(height: 8),
        Expanded(
          child: NoMatchesYet(
            activity: activity,
            onDayAdded: (created) =>
                context.pushReplacement('/matches/${created.id}'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Activity activity) {
    final header = _buildInfoRow(activity);
    if (activity.playersWanted < 2) return header;
    // The group chat itself lives in one place only: the Buddys tab.
    return Column(
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t('team.hint', {'count': '${activity.playersWanted}'}),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(Activity activity) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(activity.timeRangeLabel),
          const SizedBox(width: 16),
          Icon(Icons.place_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              activity.locationLabel ?? t('matches.flexibleLocation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBody() {
    final activity = _activity!;
    if (_candidates.isEmpty) return _buildNoMatchesYet(activity);
    final swipeable = _swipeable;
    final filteredOutEverything =
        _pending.isEmpty && _pendingUnfiltered.isNotEmpty;
    return Column(
      children: [
        _buildHeader(activity),
        _buildFilterRow(activity),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _candidates.isEmpty
                  ? t('matches.noneFoundYet')
                  : swipeable.isNotEmpty
                  ? t('matches.swipePrompt')
                  : filteredOutEverything
                  ? t('matches.noneMatchFilters')
                  : t('matches.allDoneForToday'),
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
                      t('matches.emptyHint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : swipeable.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filteredOutEverything
                              ? Icons.filter_alt_off_outlined
                              : Icons.check_circle_outline,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filteredOutEverything
                              ? t('matches.noneMatchFiltersHint')
                              : t('matches.noMoreSuggestions'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        if (filteredOutEverything) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() {
                              _filterSameTime = false;
                              _filterSamePace = false;
                            }),
                            child: Text(t('matches.clearFilters')),
                          ),
                        ],
                        if (_canUndo) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _undo,
                            icon: const Icon(Icons.undo),
                            label: Text(t('matches.undoLast')),
                          ),
                        ],
                        if (_pending.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() => _listView = true),
                            icon: const Icon(Icons.list),
                            label: Text(t('matches.viewToggleList')),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Stack(
                    children: [
                      for (
                        var i = swipeable.length.clamp(0, 2) - 1;
                        i >= 0;
                        i--
                      )
                        if (i == 0)
                          _SwipeCard(
                            key: ValueKey(swipeable[i].profile.id),
                            onSwiped: (liked) => _swipe(swipeable[i], liked),
                            child: _MatchCard(
                              candidate: swipeable[i],
                              theirSport: _theirSports[swipeable[i].profile.id],
                            ),
                          )
                        else
                          Transform.scale(
                            scale: 0.95,
                            child: Opacity(
                              opacity: 0.6,
                              child: _MatchCard(
                                candidate: swipeable[i],
                                theirSport:
                                    _theirSports[swipeable[i].profile.id],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
        ),
        if (_candidates.isNotEmpty && swipeable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundActionButton(
                  icon: Icons.undo,
                  color: AppColors.textSecondary,
                  size: 22,
                  tooltip: t('matches.undoLast'),
                  onPressed: _canUndo ? _undo : null,
                ),
                const SizedBox(width: 20),
                _RoundActionButton(
                  icon: Icons.close,
                  color: AppColors.danger,
                  onPressed: () => _swipe(swipeable.first, false),
                ),
                const SizedBox(width: 32),
                _RoundActionButton(
                  icon: Icons.favorite,
                  color: AppColors.secondary,
                  onPressed: () => _swipe(swipeable.first, true),
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
    this.size = 28,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final effectiveColor = disabled ? AppColors.border : color;
    final button = Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: effectiveColor, width: 2)),
      elevation: disabled ? 0 : 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: effectiveColor, size: size),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
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
                  child: _StampBadge(
                    label: t('matches.like'),
                    color: AppColors.secondary,
                  ),
                ),
              if (_drag.dx < -20)
                Positioned(
                  top: 20,
                  right: 20,
                  child: _StampBadge(
                    label: t('matches.nope'),
                    color: AppColors.danger,
                  ),
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

/// Stand-in for a missing profile photo: a soft gradient with the sport as
/// a large watermark and the initial in a circle — instead of an empty
/// flat area.
class _NoPhotoCover extends StatelessWidget {
  const _NoPhotoCover({required this.initial, required this.sportIcon});

  final String initial;
  final IconData sportIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondaryLight, AppColors.secondary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(
              sportIcon,
              size: 200,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Center(
            child: Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 48,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
                  SizedBox.expand(
                    child: profile.avatarUrl != null
                        ? Image.network(profile.avatarUrl!, fit: BoxFit.cover)
                        : _NoPhotoCover(
                            initial: profile.fullName.isNotEmpty
                                ? profile.fullName[0].toUpperCase()
                                : '?',
                            sportIcon: candidate.theirActivity.sport.icon,
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
                              profile.firstName,
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
                      if (candidate.likedMe) ...[
                        const _LikedMeBadge(),
                        const SizedBox(width: 6),
                      ],
                      _MatchBadge(percent: candidate.matchPercent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (profile.gender != null) genderLabel(profile.gender!),
                      candidate.theirActivity.timeRangeLabel,
                      candidate.theirActivity.locationLabel ??
                          t('matches.flexibleLocation'),
                      ?candidate.distanceLabel,
                      if (candidate.theirActivity.playersWanted > 1)
                        t('matches.lookingFor', {
                          'count': '${candidate.theirActivity.playersWanted}',
                        }),
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

/// "💚 mag dich" — they already liked me.
class _LikedMeBadge extends StatelessWidget {
  const _LikedMeBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: t('likes.likedYouLong'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t('likes.likedYou'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
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

/// Row for the list view — same info as a swipe card, condensed, with a
/// dedicated like button instead of a swipe gesture.
class _CandidateListTile extends StatelessWidget {
  const _CandidateListTile({
    required this.candidate,
    required this.theirSport,
    required this.onLike,
  });

  final MatchCandidate candidate;
  final UserSport? theirSport;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    final stats = activityStatsLabel(candidate.theirActivity, theirSport);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/profile/${profile.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
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
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              profile.firstName,
                              if (profile.age != null) '${profile.age}',
                            ].join(', '),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                        const Spacer(),
                        if (candidate.likedMe) ...[
                          const _LikedMeBadge(),
                          const SizedBox(width: 6),
                        ],
                        _MatchBadge(percent: candidate.matchPercent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        candidate.theirActivity.timeRangeLabel,
                        candidate.theirActivity.locationLabel ??
                            t('matches.flexibleLocation'),
                        ?candidate.distanceLabel,
                        if (candidate.theirActivity.playersWanted > 1)
                          t('matches.lookingFor', {
                            'count': '${candidate.theirActivity.playersWanted}',
                          }),
                      ].join(' · '),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (stats != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        stats,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onLike,
                tooltip: t('matches.likeButton'),
                icon: const Icon(Icons.favorite),
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCelebrationDialog extends StatelessWidget {
  const _MatchCelebrationDialog({required this.profile, this.groupId});
  final Profile profile;
  final String? groupId;

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
            Text(
              t('matches.celebration.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              t('matches.celebration.subtitle', {'name': profile.firstName}),
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
                  if (groupId != null) {
                    context.go('/group/$groupId');
                  } else {
                    context.go('/matches');
                  }
                },
                child: Text(
                  groupId != null
                      ? t('matches.celebration.openChat')
                      : t('matches.celebration.goToBuddies'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('matches.celebration.keepSwiping')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
