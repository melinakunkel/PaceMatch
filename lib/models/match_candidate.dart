import 'activity.dart';
import 'profile.dart';

/// Result of matching the current user's activity against another user's
/// activity: how well times / location / pace overlap, in percent.
class MatchCandidate {
  final Profile profile;
  final Activity theirActivity;
  final int matchPercent;

  MatchCandidate({
    required this.profile,
    required this.theirActivity,
    required this.matchPercent,
  });
}
