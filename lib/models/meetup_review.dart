import '../l10n/strings.dart';

/// What didn't match a participant's details after a meetup.
enum ReviewMismatch {
  pace,
  level,
  distance,
  punctuality,
  meetingPoint,
  other;

  String get label => t('group.review.mismatch.$name');
}

/// One participant's review of another after a meetup (see
/// `meetup_reviews` in the database).
class MeetupReview {
  const MeetupReview({
    required this.revieweeId,
    required this.showedUp,
    this.detailsMatched,
    this.mismatches = const {},
  });

  final String revieweeId;
  final bool showedUp;

  /// Only meaningful when [showedUp].
  final bool? detailsMatched;

  /// Only meaningful when [detailsMatched] is false.
  final Set<ReviewMismatch> mismatches;

  Map<String, dynamic> toMap({
    required String groupId,
    required String reviewerId,
  }) => {
    'group_id': groupId,
    'reviewer_id': reviewerId,
    'reviewee_id': revieweeId,
    'showed_up': showedUp,
    'details_matched': showedUp ? detailsMatched : null,
    'mismatches': showedUp && detailsMatched == false
        ? mismatches.map((m) => m.name).toList()
        : <String>[],
  };
}
