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
  /// same day (see [canMeetOnSameDay]), ranked by a 0-100 match score (time + pace overlap).
  Future<List<MatchCandidate>> findMatches(Activity myActivity) async {
    final candidates = await _activityService.getActivitiesForSport(
      sport: myActivity.sport,
      excludeUserId: myActivity.userId,
      circleId: myActivity.circleId,
    );

    final sameDay = candidates
        .where((a) => canMeetOnSameDay(myActivity, a))
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

    final myProfileRow = await _client
        .from('profiles')
        .select()
        .eq('id', myActivity.userId)
        .maybeSingle();
    final myProfile = myProfileRow == null
        ? null
        : Profile.fromMap(myProfileRow);

    final userIds = scored.map((e) => e.key.userId).toSet().toList();
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('id', userIds);
    final profilesById = {
      for (final row in profileRows) row['id'] as String: Profile.fromMap(row),
    };
    final blockedIds = await _blockService.blockedUserIds();
    // Someone already liked (for this activity) shouldn't be offered again
    // as a suggestion — whether or not it's mutual yet, that decision is
    // already made. Without this, reopening this screen re-showed everyone
    // from scratch, including people you'd already matched with.
    final likedIds = await _likeService.likedUserIdsForActivity(myActivity.id);

    final result = <MatchCandidate>[];
    for (final entry in scored) {
      final profile = profilesById[entry.key.userId];
      if (profile == null) continue;
      if (profile.isSuspended || profile.isPaused) continue;
      if (blockedIds.contains(profile.id)) continue;
      if (likedIds.contains(profile.id)) continue;
      if (myProfile != null && !isAllowedByPreferences(myProfile, profile)) {
        continue;
      }
      result.add(
        MatchCandidate(
          profile: profile,
          theirActivity: entry.key,
          matchPercent: entry.value,
        ),
      );
    }
    result.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
    return result;
  }
}
