/// Someone you and the other person both liked — a mutual connection
/// ("Sportbuddy"), not yet necessarily a chat. See LikeService.getBuddies.
/// One like between me and [userId] — received or sent, depending on
/// where it comes from.
class LikeRecord {
  LikeRecord({required this.userId, required this.likedAt, this.activityId});

  /// The other person.
  final String userId;
  final DateTime likedAt;

  /// The liker's sport time the like was made for, if any.
  final String? activityId;
}

class Buddy {
  final String userId;
  final DateTime connectedAt;
  final String? activityId;

  Buddy({required this.userId, required this.connectedAt, this.activityId});
}
