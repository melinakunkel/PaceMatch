import '../models/activity.dart';
import '../models/match_candidate.dart';
import '../models/profile.dart';
import '../utils/match_scoring.dart';
import '../utils/meeting_days.dart';
import '../utils/matching_preferences.dart';
import 'activity_service.dart';
import 'block_service.dart';
import 'supabase_service.dart';

class MatchService {
  final _client = SupabaseService.client;
  final _activityService = ActivityService();
  final _blockService = BlockService();

  /// Finds other users whose activities overlap with [myActivity] on the
  /// same day (see [canMeetOnSameDay]) and close enough to meet (see
  /// [closeEnoughToMeet]), ranked by a 0-100 match score (time + pace overlap).
  Future<List<MatchCandidate>> findMatches(Activity myActivity) async =>
      (await findMatchesForAll([myActivity]))[myActivity.id] ?? [];

  /// [findMatches] for several of my activities at once (activity id →
  /// candidates) — one query per sport instead of five per activity, all
  /// in parallel. The Buddys tab used to take 10–20 s doing it one by one.
  Future<Map<String, List<MatchCandidate>>> findMatchesForAll(
    List<Activity> mine,
  ) async {
    if (mine.isEmpty) return {};
    final myUserId = mine.first.userId;

    // Everyone else's activities, fetched once per sport/Kreis.
    final keys = {for (final a in mine) (a.sport, a.circleId)}.toList();
    final pools = await Future.wait(
      keys.map(
        (k) => _activityService.getActivitiesForSport(
          sport: k.$1,
          excludeUserId: myUserId,
          circleId: k.$2,
        ),
      ),
    );
    final poolByKey = {for (var i = 0; i < keys.length; i++) keys[i]: pools[i]};

    final scoredByActivity = <String, List<MapEntry<Activity, int>>>{};
    for (final myActivity in mine) {
      final scored = <MapEntry<Activity, int>>[];
      for (final other in poolByKey[(myActivity.sport, myActivity.circleId)]!) {
        if (!canMeetOnSameDay(myActivity, other) ||
            !closeEnoughToMeet(myActivity, other)) {
          continue;
        }
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
      scoredByActivity[myActivity.id] = scored;
    }

    final allUserIds = {
      for (final list in scoredByActivity.values)
        for (final e in list) e.key.userId,
    };
    if (allUserIds.isEmpty) return {for (final a in mine) a.id: []};

    final results = await Future.wait([
      _eligibleProfiles(myUserId, allUserIds),
      _likedByActivity(myUserId),
    ]);
    final eligible = results[0] as Map<String, Profile>;
    // Someone already liked (for this activity) shouldn't be offered again
    // as a suggestion — whether or not it's mutual yet, that decision is
    // already made.
    final liked = results[1] as Map<String, Set<String>>;

    return {
      for (final myActivity in mine)
        myActivity.id: [
          for (final entry in scoredByActivity[myActivity.id]!)
            if (eligible[entry.key.userId] != null &&
                !(liked[myActivity.id]?.contains(entry.key.userId) ?? false))
              MatchCandidate(
                profile: eligible[entry.key.userId]!,
                theirActivity: entry.key,
                matchPercent: entry.value,
                distanceKm: meetingDistanceKm(myActivity, entry.key),
              ),
        ]..sort((a, b) => b.matchPercent.compareTo(a.matchPercent)),
    };
  }

  /// Who I've liked, per my activity — one query for all of them.
  Future<Map<String, Set<String>>> _likedByActivity(String myUserId) async {
    final rows = await _client
        .from('likes')
        .select('to_user, activity_id')
        .eq('from_user', myUserId);
    final result = <String, Set<String>>{};
    for (final row in rows) {
      final activityId = row['activity_id'] as String?;
      if (activityId == null) continue;
      (result[activityId] ??= {}).add(row['to_user'] as String);
    }
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
    final results = await Future.wait<Object?>([
      _client.from('profiles').select().eq('id', myUserId).maybeSingle(),
      _client.from('profiles').select().inFilter('id', ids),
      _blockService.blockedUserIds(),
    ]);
    final myProfileRow = results[0] as Map<String, dynamic>?;
    final myProfile = myProfileRow == null
        ? null
        : Profile.fromMap(myProfileRow);
    final profileRows = results[1] as List<Map<String, dynamic>>;
    final blockedIds = results[2] as Set<String>;
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
