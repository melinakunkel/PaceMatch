import '../models/activity.dart';
import 'match_scoring.dart';

/// One sport time two people have in common: same sport, same day,
/// overlapping time window — what their private chat can page through.
class SharedSportTime {
  const SharedSportTime({required this.mine, required this.theirs});

  final Activity mine;
  final Activity theirs;

  /// When it happens next (from my side's schedule).
  DateTime get nextOccurrence => mine.nextOccurrence;

  /// Where to meet: my place if I set one, otherwise theirs.
  String? get locationName => mine.locationName ?? theirs.locationName;
  double? get latitude =>
      mine.locationName != null ? mine.latitude : theirs.latitude;
  double? get longitude =>
      mine.locationName != null ? mine.longitude : theirs.longitude;

  bool involves(String? activityId) =>
      activityId != null && (mine.id == activityId || theirs.id == activityId);
}

/// Pairs each of [mine] with the best-overlapping of [theirs] — same sport,
/// same weekday (and same date if both are one-offs), overlapping times,
/// same "Kreis". Sorted by what's coming up next.
List<SharedSportTime> sharedSportTimes(
  List<Activity> mine,
  List<Activity> theirs, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  bool isOver(Activity a) =>
      a.specificDate != null && _dateOnly(a.specificDate!).isBefore(today);

  final result = <SharedSportTime>[];
  for (final m in mine) {
    if (isOver(m)) continue;
    SharedSportTime? best;
    var bestScore = 0;
    for (final o in theirs) {
      if (isOver(o)) continue;
      if (o.sport != m.sport || o.dayOfWeek != m.dayOfWeek) continue;
      if (o.circleId != m.circleId) continue;
      final md = m.specificDate;
      final od = o.specificDate;
      if (md != null &&
          od != null &&
          (md.year != od.year || md.month != od.month || md.day != od.day)) {
        continue;
      }
      final score = matchScore(
        myStart: m.startTime,
        myEnd: m.endTime,
        otherStart: o.startTime,
        otherEnd: o.endTime,
        myPaceMin: m.paceMin,
        myPaceMax: m.paceMax,
        otherPaceMin: o.paceMin,
        otherPaceMax: o.paceMax,
      );
      if (score > bestScore) {
        bestScore = score;
        best = SharedSportTime(mine: m, theirs: o);
      }
    }
    if (best != null) result.add(best);
  }
  result.sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
  return result;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
