import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/match_candidate.dart';
import '../models/profile.dart';
import '../utils/matching_preferences.dart';
import 'activity_service.dart';
import 'supabase_service.dart';

class MatchService {
  final _client = SupabaseService.client;
  final _activityService = ActivityService();

  /// Finds other users whose activities overlap with [myActivity] on the
  /// same weekday, ranked by a 0-100 match score (time + pace overlap).
  Future<List<MatchCandidate>> findMatches(Activity myActivity) async {
    final candidates = await _activityService.getActivitiesForSport(
      sport: myActivity.sport,
      excludeUserId: myActivity.userId,
      circleId: myActivity.circleId,
    );

    final sameDay = candidates
        .where((a) => a.dayOfWeek == myActivity.dayOfWeek)
        .toList();
    if (sameDay.isEmpty) return [];

    final scored = <MapEntry<Activity, int>>[];
    for (final other in sameDay) {
      final score = _matchScore(myActivity, other);
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

    final result = <MatchCandidate>[];
    for (final entry in scored) {
      final profile = profilesById[entry.key.userId];
      if (profile == null) continue;
      if (myProfile != null && !isAllowedByPreferences(myProfile, profile))
        continue;
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

  int _matchScore(Activity mine, Activity other) {
    final timeScore = _overlapRatio(
      _toMinutes(mine.startTime),
      _toMinutes(mine.endTime),
      _toMinutes(other.startTime),
      _toMinutes(other.endTime),
    );
    if (timeScore == 0) return 0;

    final paceScore = _rangeOverlapRatio(
      mine.paceMin,
      mine.paceMax,
      other.paceMin,
      other.paceMax,
    );

    final combined = timeScore * 0.6 + paceScore * 0.4;
    return (combined * 100).round().clamp(0, 99);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  double _overlapRatio(int aStart, int aEnd, int bStart, int bEnd) {
    final overlapStart = aStart > bStart ? aStart : bStart;
    final overlapEnd = aEnd < bEnd ? aEnd : bEnd;
    final overlap = overlapEnd - overlapStart;
    if (overlap <= 0) return 0;
    final unionSpan =
        (aEnd > bEnd ? aEnd : bEnd) - (aStart < bStart ? aStart : bStart);
    if (unionSpan <= 0) return 0;
    return overlap / unionSpan;
  }

  double _rangeOverlapRatio(
    double? aMin,
    double? aMax,
    double? bMin,
    double? bMax,
  ) {
    if (aMin == null || aMax == null || bMin == null || bMax == null) {
      return 0.7; // neutral score when pace data is missing
    }
    final overlapStart = aMin > bMin ? aMin : bMin;
    final overlapEnd = aMax < bMax ? aMax : bMax;
    final overlap = overlapEnd - overlapStart;
    if (overlap <= 0) return 0.2;
    final unionSpan = (aMax > bMax ? aMax : bMax) - (aMin < bMin ? aMin : bMin);
    if (unionSpan <= 0) return 1;
    return (overlap / unionSpan).clamp(0.2, 1.0);
  }
}
