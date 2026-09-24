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

/// My own anonymous review breakdown — what lowered my sub-scores. Only
/// ever loaded for the signed-in user (see `my_review_summary()`).
class ReviewSummary {
  const ReviewSummary({
    required this.total,
    required this.showedUp,
    required this.ratedDetails,
    required this.detailsMatched,
    required this.mismatches,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['mismatches'] as Map?) ?? const {};
    final mismatches = <ReviewMismatch, int>{};
    for (final m in ReviewMismatch.values) {
      final count = (raw[m.name] as num?)?.toInt() ?? 0;
      if (count > 0) mismatches[m] = count;
    }
    return ReviewSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      showedUp: (json['showed_up'] as num?)?.toInt() ?? 0,
      ratedDetails: (json['rated_details'] as num?)?.toInt() ?? 0,
      detailsMatched: (json['details_matched'] as num?)?.toInt() ?? 0,
      mismatches: mismatches,
    );
  }

  final int total;
  final int showedUp;
  final int ratedDetails;
  final int detailsMatched;

  /// How often each detail was marked as not matching.
  final Map<ReviewMismatch, int> mismatches;
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
