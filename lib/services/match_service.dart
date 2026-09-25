import '../models/activity.dart';
import '../models/match_candidate.dart';
import '../models/profile.dart';
import '../utils/match_scoring.dart';
import '../utils/meeting_days.dart';
import '../utils/matching_preferences.dart';
import 'activity_service.dart';
import 'block_service.dart';
import 'like_service.dart';
import 'supabase_service.dart';

class MatchService {
  final _client = SupabaseService.client;
  final _activityService = ActivityService();
  final _blockService = BlockService();
  final _likeService = LikeService();

  /// Finds other users whose activities overlap with [myActivity] on the
  /// same day (see [canMeetOnSameDay]) and close enough to meet (see
  /// [closeEnoughToMeet]), ranked by a 0-100 match score (time + pace overlap).
  Future<List<MatchCandidate>> findMatches(Activity myActivity) async {
    final candidates = await _activityService.getActivitiesForSport(
      sport: myActivity.sport,
      excludeUserId: myActivity.userId,
      circleId: myActivity.circleId,
    );

    final sameDay = candidates
        .where(
          (a) =>
              canMeetOnSameDay(myActivity, a) &&
              closeEnoughToMeet(myActivity, a),
        )
        .toList();
    if (sameDay.isEmpty) return [];

    final scored = <MapEntry<Activity, int>>[];
    for (final other in sameDay) {
      final score = matchScore(
        myStart: myActivity.startTime,
        myEnd: myActivity.endTime,
        otherStart: other.startTime,
        otherEnd: other.endTime,
        myPaceMin: myActivity.paceMin,
        myPaceMax: myActivity.paceMax,
        otherPaceMin: other.paceMin,
        otherPaceMax: other.paceMax,
      );
      if (score > 0) scored.add(MapEntry(other, score));
    }
    if (scored.isEmpty) return [];

    final eligible = await _eligibleProfiles(
      myActivity.userId,
      scored.map((e) => e.key.userId),
    );
    // Someone already liked (for this activity) shouldn't be offered again
    // as a suggestion — whether or not it's mutual yet, that decision is
    // already made. Without this, reopening this screen re-showed everyone
    // from scratch, including people you'd already matched with.
    final likedIds = await _likeService.likedUserIdsForActivity(myActivity.id);

    final result = <MatchCandidate>[];
    for (final entry in scored) {
      final profile = eligible[entry.key.userId];
      if (profile == null) continue;
      if (likedIds.contains(profile.id)) continue;
      result.add(
        MatchCandidate(
          profile: profile,
          theirActivity: entry.key,
          matchPercent: entry.value,
          distanceKm: meetingDistanceKm(myActivity, entry.key),
        ),
      );
    }
    result.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
    return result;
  }

  /// Almost-matches for [myActivity] — shown instead of an empty list while
  /// nobody fits exactly (see [splitNearMisses]). One entry per person.
  Future<NearMisses> findNearMisses(Activity myActivity) async {
    final others = await _activityService.getActivitiesForSport(
      sport: myActivity.sport,
      excludeUserId: myActivity.userId,
      circleId: myActivity.circleId,
    );
    final split = splitNearMisses(myActivity, others);
    if (split.isEmpty) return const NearMisses();
    final eligible = await _eligibleProfiles(myActivity.userId, [
      for (final list in split.otherDays.values) ...list.map((a) => a.userId),
      ...split.otherTimes.map((a) => a.userId),
    ]);

    List<MatchCandidate> toCandidates(List<Activity> activities) {
      final seen = <String>{};
      return [
        for (final a in activities)
          if (eligible[a.userId] != null && seen.add(a.userId))
            MatchCandidate(
              profile: eligible[a.userId]!,
              theirActivity: a,
              matchPercent: 0,
              distanceKm: meetingDistanceKm(myActivity, a),
            ),
      ];
    }

    final otherDays = <int, List<MatchCandidate>>{};
    for (final entry in split.otherDays.entries) {
      final list = toCandidates(entry.value);
      if (list.isNotEmpty) otherDays[entry.key] = list;
    }
    return NearMisses(
      otherDays: otherDays,
      otherTimes: toCandidates(split.otherTimes),
    );
  }

  /// Profiles of [userIds] that may be shown to me at all: not paused,
  /// suspended or blocked (either way), and within both people's
  /// preferences.
  Future<Map<String, Profile>> _eligibleProfiles(
    String myUserId,
    Iterable<String> userIds,
  ) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};
    final myProfileRow = await _client
        .from('profiles')
        .select()
        .eq('id', myUserId)
        .maybeSingle();
    final myProfile = myProfileRow == null
        ? null
        : Profile.fromMap(myProfileRow);
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('id', ids);
    final blockedIds = await _blockService.blockedUserIds();
    return {
      for (final row in profileRows)
        if (_isEligible(Profile.fromMap(row), myProfile, blockedIds))
          row['id'] as String: Profile.fromMap(row),
    };
  }

  static bool _isEligible(
    Profile profile,
    Profile? me,
    Set<String> blockedIds,
  ) {
    if (profile.isSuspended || profile.isPaused) return false;
    if (blockedIds.contains(profile.id)) return false;
    if (me != null && !isAllowedByPreferences(me, profile)) return false;
    return true;
  }
}

/// See [MatchService.findNearMisses].
class NearMisses {
  const NearMisses({this.otherDays = const {}, this.otherTimes = const []});

  final Map<int, List<MatchCandidate>> otherDays;
  final List<MatchCandidate> otherTimes;

  bool get isEmpty => otherDays.isEmpty && otherTimes.isEmpty;
}
