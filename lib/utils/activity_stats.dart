import '../models/activity.dart';
import '../models/user_sport.dart';
import 'pace_format.dart';

/// A short summary of an activity's pace/distance (or skill level, for
/// sports where pace doesn't apply), e.g. "4:15 - 4:45 /km · 8 - 10 km" or
/// "Fortgeschritten".
String? activityStatsLabel(Activity activity, UserSport? theirSport) {
  final sport = activity.sport;
  final parts = <String>[];
  if (sport.usesPace && activity.paceMin != null && activity.paceMax != null) {
    parts.add(
      paceRangeLabel(activity.paceMin!, activity.paceMax!, sport.defaultUnit),
    );
  } else if (!sport.usesPace && theirSport?.level != null) {
    parts.add(theirSport!.level!);
  }
  if (sport.usesDistance &&
      activity.distanceMinKm != null &&
      activity.distanceMaxKm != null) {
    parts.add(
      '${_formatKm(activity.distanceMinKm!)} - ${_formatKm(activity.distanceMaxKm!)} km',
    );
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String _formatKm(double km) =>
    km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
