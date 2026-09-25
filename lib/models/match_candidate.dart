import 'activity.dart';
import 'profile.dart';

/// Result of matching the current user's activity against another user's
/// activity: how well times / location / pace overlap, in percent.
class MatchCandidate {
  final Profile profile;
  final Activity theirActivity;
  final int matchPercent;

  /// Between the two meeting points, when both have one.
  final double? distanceKm;

  MatchCandidate({
    required this.profile,
    required this.theirActivity,
    required this.matchPercent,
    this.distanceKm,
  });

  /// "2,4 km" / "800 m", for the match cards.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    if (km < 1) return '${(km * 1000 / 100).round() * 100} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}
